"""Native build entry-point failure and relocation contracts (no compiler)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class NativeBuildContractTest(unittest.TestCase):
    def setUp(self):
        Path("/tmp/agent-runs").mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="native-build-contract-", dir="/tmp/agent-runs")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "native/third_party/llama.cpp").mkdir(parents=True)
        (self.root / "native/patches").mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        source = Path(__file__).resolve().parents[2] / "scripts/native_build.sh"
        shutil.copy2(source, self.root / "scripts/native_build.sh")
        self.executable("cmake", '#!/bin/sh\nprintf "%s\\n" "$*" >> cmake-invocations\n')
        self.executable("git", '#!/bin/sh\nexit 0\n')
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}")
        self.env.pop("PSY_NATIVE_BUILD_DIR", None)

    def executable(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)

    def run_build(self):
        return subprocess.run(["bash", "scripts/native_build.sh"], cwd=self.root,
                              env=self.env, text=True, capture_output=True, check=False)

    def present_submodule(self):
        (self.root / "native/third_party/llama.cpp/CMakeLists.txt").write_text("# fixture\n")

    def test_missing_submodule_fails_before_cmake(self):
        result = self.run_build()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Missing llama.cpp submodule", result.stderr)
        self.assertFalse((self.root / "cmake-invocations").exists())

    def test_incompatible_patch_is_not_reported_as_already_applied(self):
        self.present_submodule()
        (self.root / "native/patches/regression.patch").write_text("invalid patch\n")
        self.executable("git", '#!/bin/sh\necho "patch does not apply" >&2\nexit 1\n')
        result = self.run_build()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Incompatible pinned patch", result.stderr)
        self.assertFalse((self.root / "cmake-invocations").exists())

    def test_reverse_check_proves_an_already_applied_patch(self):
        self.present_submodule()
        (self.root / "native/patches/regression.patch").write_text("patch fixture\n")
        self.executable("git", '#!/bin/sh\ncase "$*" in *--reverse*) exit 0;; *) exit 1;; esac\n')
        result = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already applied regression.patch", result.stdout)

    def test_relocated_cache_is_preserved_and_fresh_build_configured(self):
        self.present_submodule()
        build = self.root / "native/build/current"
        build.mkdir(parents=True)
        old_cache = "CMAKE_HOME_DIRECTORY:INTERNAL=/old/native\nCMAKE_CACHEFILE_DIR:INTERNAL=/old/native/build\n"
        (build / "CMakeCache.txt").write_text(old_cache)
        (build / "user-artifact").write_text("preserve me")
        legacy = self.root / "native/build/CMakeCache.txt"
        legacy.write_text("legacy preserved")
        result = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        preserved = list(build.parent.glob("current.relocated.*"))
        self.assertEqual(len(preserved), 1)
        self.assertEqual((preserved[0] / "CMakeCache.txt").read_text(), old_cache)
        self.assertEqual((preserved[0] / "user-artifact").read_text(), "preserve me")
        self.assertEqual(legacy.read_text(), "legacy preserved")
        invocations = (self.root / "cmake-invocations").read_text()
        self.assertIn(f"-S native -B {build}", invocations)
        self.assertIn(f"--build {build}", invocations)


if __name__ == "__main__":
    unittest.main()

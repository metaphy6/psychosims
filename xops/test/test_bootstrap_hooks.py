"""Bootstrap contracts exercised with isolated repositories and fake SDKs."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]


class BootstrapHookTests(unittest.TestCase):
    def setUp(self):
        Path('/tmp/agent-runs').mkdir(exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(prefix='bootstrap-hooks-', dir='/tmp/agent-runs')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for name in ('scripts', '.githooks', 'bin', 'app', 'config',
                     'packages/psychemas', 'packages/psycore', 'tools', 'server'):
            (self.root / name).mkdir(parents=True, exist_ok=True)
        for name in ('scripts/bootstrap.sh', 'scripts/install_git_hooks.sh', '.githooks/pre-commit'):
            source = REPO_ROOT / name
            if source.exists():
                shutil.copy2(source, self.root / name)
        self.env = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.env.update(PATH=f'{self.root}/bin:/usr/bin:/bin',
                        GIT_CONFIG_GLOBAL=str(self.root / 'global-config'),
                        GIT_CONFIG_NOSYSTEM='1', FIXTURE_ARGS=str(self.root / 'args'))
        self.git('init', '-q')

    def git(self, *args, check=True):
        return subprocess.run(['git', *args], cwd=self.root, env=self.env,
                              capture_output=True, text=True, check=check)

    def tool(self, name, body):
        path = self.root / 'bin' / name
        path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(['bash', str(self.root / name), *args], cwd=self.root / 'app',
                              env=self.env, capture_output=True, text=True)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def fake_sdks(self):
        cache = self.root / 'module-cache'
        (cache / 'github.com/google/licenseclassifier@v0.0.0-20260218193730-3cfbab2d0e0d/licenses').mkdir(parents=True)
        self.env['FIXTURE_MODULE_CACHE'] = str(cache)
        self.tool('go', '''case "$1" in
  env) echo "$FIXTURE_MODULE_CACHE" ;;
  version) echo 'go version go1.26.7 linux/amd64' ;;
  install)
    if [[ "$2" == *license_serializer* ]]; then
      printf '#!/bin/bash\nexit 0\n' > "$GOBIN/license_serializer"
      chmod +x "$GOBIN/license_serializer"
    fi ;;
esac''')
        for name, version in (('flutter', 'Flutter 3.38.5'), ('dart', 'Dart SDK version: 3.10.4')):
            self.tool(name, f'''if [[ "$1" == --version ]]; then echo '{version}'; exit 0; fi
printf '%s|%s|%s\\n' '{name}' "$PWD" "$*" >> "$FIXTURE_ARGS"
if [[ "${{FIXTURE_FAIL_PACKAGE:-}}" == "${{PWD##*/}}" ]]; then exit 29; fi''')

    def test_install_is_local_and_idempotent(self):
        global_config = self.root / 'global-config'
        global_config.write_text('[user]\n\tname = fixture\n')
        before_global = global_config.read_bytes()
        self.assert_ok(self.run_script('scripts/install_git_hooks.sh'))
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath').stdout.strip(), '.githooks')
        before = (self.root / '.git/config').read_bytes()
        self.assert_ok(self.run_script('scripts/install_git_hooks.sh'))
        self.assertEqual((self.root / '.git/config').read_bytes(), before)
        self.assertEqual(global_config.read_bytes(), before_global)

    def test_different_local_or_inherited_hooks_are_preserved(self):
        for scope in ('local', 'inherited'):
            with self.subTest(scope=scope):
                if scope == 'local':
                    self.git('config', '--local', 'core.hooksPath', '/custom hooks')
                else:
                    (self.root / 'global-config').write_text('[core]\n\thooksPath = /custom hooks\n')
                before = (self.root / '.git/config').read_bytes()
                result = self.run_script('scripts/install_git_hooks.sh')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('custom core.hooksPath', result.stderr)
                self.assertEqual(self.git('config', '--get', 'core.hooksPath').stdout.strip(), '/custom hooks')
                self.assertEqual((self.root / '.git/config').read_bytes(), before)
                if scope == 'local':
                    self.git('config', '--local', '--unset', 'core.hooksPath')
                else:
                    (self.root / 'global-config').unlink()

    def test_existing_default_hook_is_preserved(self):
        hook = self.root / '.git/hooks/pre-commit'
        hook.write_text('#!/bin/sh\nexit 23\n')
        hook.chmod(0o755)
        before = hook.read_bytes()
        result = self.run_script('scripts/install_git_hooks.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('existing default pre-commit', result.stderr)
        self.assertEqual(hook.read_bytes(), before)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath', check=False).returncode, 1)

    def test_other_default_hooks_remain_executable_after_install_refusal(self):
        for name, symlink in (('pre-push', False), ('commit-msg', False),
                              ('post-checkout', False), ('post-merge', True)):
            with self.subTest(name=name, symlink=symlink):
                hook = self.root / '.git/hooks' / name
                target = self.root / 'custom-hook'
                body = '#!/bin/sh\nprintf "preserved\\n" > "$FIXTURE_ARGS"\nexit 23\n'
                if symlink:
                    target.write_text(body)
                    target.chmod(0o755)
                    hook.symlink_to(target)
                else:
                    hook.write_text(body)
                    hook.chmod(0o755)
                self.assertEqual(self.git('hook', 'run', name, check=False).returncode, 23)
                (self.root / 'args').unlink()
                before = (self.root / '.git/config').read_bytes()
                result = self.run_script('scripts/install_git_hooks.sh')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('existing default', result.stderr)
                self.assertEqual((self.root / '.git/config').read_bytes(), before)
                self.assertEqual(self.git('hook', 'run', name, check=False).returncode, 23)
                self.assertEqual((self.root / 'args').read_text(), 'preserved\n')
                self.assertEqual(hook.read_text(), body)
                self.assertEqual(hook.is_symlink(), symlink)
                hook.unlink()

    def test_default_sample_files_do_not_block_installation(self):
        sample = self.root / '.git/hooks/pre-push.sample'
        sample.write_text('#!/bin/sh\nexit 23\n')
        sample.chmod(0o755)
        self.assert_ok(self.run_script('scripts/install_git_hooks.sh'))
        self.assertEqual(sample.read_text(), '#!/bin/sh\nexit 23\n')

    def test_missing_or_nonexecutable_repository_hook_fails(self):
        hook = self.root / '.githooks/pre-commit'
        hook.chmod(0o644)
        result = self.run_script('scripts/install_git_hooks.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('executable', result.stderr)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath', check=False).returncode, 1)

    def test_hook_runs_contracts_from_root_and_propagates_failure(self):
        self.tool('make', 'printf "%s|%s\\n" "$PWD" "$*" > "$FIXTURE_ARGS"; exit 31')
        result = self.run_script('.githooks/pre-commit')
        self.assertEqual(result.returncode, 31, result.stdout + result.stderr)
        self.assertEqual((self.root / 'args').read_text().strip(), f'{self.root}|verify.contracts')

    def test_git_invokes_the_installed_hook_and_propagates_failure(self):
        self.tool('make', 'printf "%s|%s\\n" "$PWD" "$*" > "$FIXTURE_ARGS"; exit 31')
        self.assert_ok(self.run_script('scripts/install_git_hooks.sh'))
        result = self.git('hook', 'run', 'pre-commit', check=False)
        self.assertEqual(result.returncode, 31, result.stdout + result.stderr)
        self.assertEqual((self.root / 'args').read_text().strip(), f'{self.root}|verify.contracts')

    def test_configuration_write_failure_is_propagated(self):
        lock = self.root / '.git/config.lock'
        lock.write_text('another writer owns this lock')
        before = (self.root / '.git/config').read_bytes()
        result = self.run_script('scripts/install_git_hooks.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('could not lock config file', result.stderr)
        self.assertNotIn('Installed repository hooks', result.stdout)
        self.assertEqual((self.root / '.git/config').read_bytes(), before)
        self.assertEqual(lock.read_text(), 'another writer owns this lock')

    def test_copied_installer_in_nested_directory_cannot_modify_parent_repo(self):
        nested = self.root / 'nested/scripts'
        nested.mkdir(parents=True)
        shutil.copy2(self.root / 'scripts/install_git_hooks.sh', nested)
        before = (self.root / '.git/config').read_bytes()
        result = self.run_script('nested/scripts/install_git_hooks.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('outside this repository root', result.stderr)
        self.assertEqual((self.root / '.git/config').read_bytes(), before)

    def test_full_bootstrap_enforces_all_lockfiles_and_installs_hook(self):
        self.fake_sdks()
        self.assert_ok(self.run_script('scripts/bootstrap.sh'))
        calls = (self.root / 'args').read_text().splitlines()
        expected = [f'{sdk}|{self.root / pkg}|pub get --enforce-lockfile'
                    for sdk, pkg in [('flutter', 'app'), ('dart', 'config'),
                                     ('dart', 'packages/psychemas'), ('dart', 'packages/psycore'), ('dart', 'tools')]]
        self.assertEqual(calls, expected)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath').stdout.strip(), '.githooks')

    def test_tools_only_does_not_mutate_git_or_fetch_dart(self):
        self.fake_sdks()
        self.git('config', '--local', 'core.hooksPath', '/custom hooks')
        before = (self.root / '.git/config').read_bytes()
        self.assert_ok(self.run_script('scripts/bootstrap.sh', '--tools-only'))
        self.assertEqual((self.root / '.git/config').read_bytes(), before)
        self.assertFalse((self.root / 'args').exists())

    def test_failed_dependency_prevents_hook_installation(self):
        self.fake_sdks()
        self.env['FIXTURE_FAIL_PACKAGE'] = 'tools'
        result = self.run_script('scripts/bootstrap.sh')
        self.assertEqual(result.returncode, 29, result.stdout + result.stderr)
        self.assertEqual(self.git('config', '--local', '--get', 'core.hooksPath', check=False).returncode, 1)

    def test_full_bootstrap_propagates_hook_conflict(self):
        self.fake_sdks()
        self.git('config', '--local', 'core.hooksPath', '/custom hooks')
        result = self.run_script('scripts/bootstrap.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('custom core.hooksPath', result.stderr)
        self.assertNotIn('bootstrap complete', result.stdout)

    def test_tools_only_rejects_extra_arguments_without_work(self):
        self.fake_sdks()
        result = self.run_script('scripts/bootstrap.sh', '--tools-only', 'unexpected')
        self.assertEqual(result.returncode, 64, result.stdout + result.stderr)
        self.assertFalse((self.root / '.tools').exists())

    def test_environment_example_uses_real_config_names_without_values(self):
        example = (REPO_ROOT / '.env.example').read_text()
        names = re.findall(r'^([A-Z][A-Z0-9_]*)=(.*)$', example, re.MULTILINE)
        source = (REPO_ROOT / 'server/internal/config/config.go').read_text()
        self.assertGreater(len(names), 4)
        for name, value in names:
            self.assertIn(f'"{name}"', source)
            self.assertEqual(value, '')
        self.assertIn('PSY_TOKEN_SECRET_FILE', dict(names))
        self.assertIn('not automatically', example)

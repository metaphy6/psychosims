"""Require actual scanner coverage; a tool's zero exit alone is insufficient."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('dependency_scan', ROOT / 'scripts/dependency_scan.py')
scan = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scan)


class DependencyScanTests(unittest.TestCase):
    def test_native_commit_is_not_misidentified_as_a_github_actions_package(self):
        packages = scan.packages_from_inventory({'components': [
            {'bom-ref': 'native:llama.cpp@abc', 'name': 'llama.cpp', 'version': 'abc'},
            {'bom-ref': 'pkg:pub/crypto@3.0.7', 'name': 'crypto', 'version': '3.0.7'}]})
        self.assertEqual(packages[0]['package'], {'name': 'llama.cpp', 'ecosystem': 'GIT', 'commit': 'abc'})
        self.assertEqual(packages[1]['package']['ecosystem'], 'Pub')

    def test_empty_or_dropped_scanner_results_fail(self):
        requested = [{'package': {'name': 'crypto', 'version': '3.0.7', 'ecosystem': 'Pub'}}]
        with self.assertRaisesRegex(ValueError, 'dropped'):
            scan.verify_coverage(requested, {})
        scan.verify_coverage(requested, {'results': [{'packages': requested}]})

    def test_wrong_version_is_not_coverage(self):
        requested = [{'package': {'name': 'crypto', 'version': '3.0.7', 'ecosystem': 'Pub'}}]
        wrong = [{'package': {'name': 'crypto', 'version': '3.0.6', 'ecosystem': 'Pub'}}]
        with self.assertRaises(ValueError):
            scan.verify_coverage(requested, {'results': [{'packages': wrong}]})


if __name__ == '__main__':
    unittest.main()

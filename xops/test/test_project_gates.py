"""Behavior checks for project gates, using isolated tools and fixture trees."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ProjectGateTests(unittest.TestCase):
    def setUp(self):
        run_dir = Path('/tmp/agent-runs')
        run_dir.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix='quality-gates-', dir=run_dir)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('scripts', 'bin', 'config', 'packages/psychemas',
                          'packages/psycore', 'app', 'server', 'content/manifests',
                          'test_fixtures', 'tools'):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'content/fictional_taxonomy.yaml',
                     self.root / 'content/fictional_taxonomy.yaml')
        self.env = {**os.environ, 'PATH': f'{self.root}/bin:/usr/bin:/bin',
                    'GATE_ARGS_PATH': str(self.root / 'args')}

    def tool(self, name, body):
        path = self.root / 'bin' / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)

    def run_gate(self, name, *args):
        target = self.root / 'scripts' / name
        shutil.copy2(ROOT / 'scripts' / name, target)
        helper = ROOT / 'scripts' / name.replace('.sh', '.py')
        if helper.is_file():
            shutil.copy2(helper, self.root / 'scripts' / helper.name)
        if name == 'secret_check.sh' and (ROOT / '.gitleaks.toml').is_file():
            shutil.copy2(ROOT / '.gitleaks.toml', self.root / '.gitleaks.toml')
        return subprocess.run(['bash', str(target), *args], cwd=self.root,
                              env=self.env, capture_output=True, text=True)

    def test_format_check_is_read_only_and_propagates_failure(self):
        self.tool('dart', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"; exit 23')
        result = self.run_gate('dart_format.sh', '--check')
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertIn('--output=none', (self.root / 'args').read_text().splitlines())
        self.assertIn('--set-exit-if-changed', (self.root / 'args').read_text())

    def test_format_write_mode_still_formats(self):
        self.tool('dart', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"')
        result = self.run_gate('dart_format.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('--output=none', (self.root / 'args').read_text())

    def test_content_accepts_validator_registry_and_fictional_manifest(self):
        shutil.copy2(ROOT / 'content/fictional_taxonomy.yaml',
                     self.root / 'content/fictional_taxonomy.yaml')
        (self.root / 'content/manifests/good.json').write_text('{"name":"Brumosis"}')
        result = self.run_gate('content_integrity_check.sh')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_content_rejects_banned_term_in_product_content(self):
        (self.root / 'content/manifests/bad case.json').write_text('{"name":"Schizophrenia"}')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('bad case.json', result.stdout + result.stderr)

    def test_content_cannot_bypass_validation_by_registry_filename(self):
        (self.root / 'content/manifests/fictional_taxonomy.yaml').write_text('name: schizophrenia')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_missing_content_input_cannot_pass(self):
        shutil.rmtree(self.root / 'content')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_content_enforces_all_registry_patterns(self):
        target = self.root / 'content/manifests/unsafe.json'
        for term in ['Prozac', 'PTSD', 'ADHD', 'depression', 'bipolar', 'DSM V',
                     'DSM-IV', 'major depressive disorder']:
            with self.subTest(term=term):
                target.write_text('{"name":"' + term + '"}')
                result = self.run_gate('content_integrity_check.sh')
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn('unsafe.json', result.stdout + result.stderr)

    def test_content_registry_changes_are_effective(self):
        registry = self.root / 'content/fictional_taxonomy.yaml'
        registry.write_text('forbidden_patterns:\n  - "(?i)forbidden_fixture"\n')
        (self.root / 'test_fixtures/name.json').write_text('FORBIDDEN_FIXTURE')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_content_registry_missing_empty_or_invalid_fails(self):
        registry = self.root / 'content/fictional_taxonomy.yaml'
        for data in [None, '', 'forbidden_patterns: []',
                     'forbidden_patterns:\n  - "["\n']:
            with self.subTest(data=data):
                if data is None:
                    registry.unlink()
                else:
                    registry.write_text(data)
                result = self.run_gate('content_integrity_check.sh')
                self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_content_rejects_invalid_encoding(self):
        (self.root / 'content/manifests/bytes.json').write_bytes(b'\xff\xfe')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_content_json_escapes_cannot_hide_forbidden_labels(self):
        (self.root / 'content/manifests/escaped.json').write_text(
            '{"name":"\\u0050rozac"}')
        result = self.run_gate('content_integrity_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('escaped.json', result.stdout + result.stderr)

    def test_content_rejects_linked_files_and_directories(self):
        outside = self.root / 'unscanned'
        outside.mkdir()
        (outside / 'bad.json').write_text('{"name":"schizophrenia"}')
        for name, target in [('linked.json', outside / 'bad.json'),
                             ('linked-dir', outside)]:
            with self.subTest(name=name):
                link = self.root / 'content/manifests' / name
                link.symlink_to(target)
                result = self.run_gate('content_integrity_check.sh')
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn('symbolic link', result.stdout + result.stderr)
                link.unlink()

    def test_privacy_gate_runs_real_storage_boundaries_and_propagates_failure(self):
        self.tool('flutter', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"; exit 29')
        result = self.run_gate('no_transcripts_check.sh')
        self.assertEqual(result.returncode, 29, result.stdout + result.stderr)
        args = (self.root / 'args').read_text().splitlines()
        self.assertIn('test/session_persistence_test.dart', args)
        self.assertIn('test/signed_receipt_queue_test.dart', args)

    def test_privacy_gate_does_not_succeed_without_durable_server_checks(self):
        self.tool('flutter', 'exit 0')
        script = self.root / 'server/scripts/postgres_test.sh'
        script.parent.mkdir(parents=True)
        script.write_text('#!/bin/bash\necho "durable server privacy fixture" >&2\nexit 33\n')
        result = self.run_gate('no_transcripts_check.sh')
        self.assertEqual(result.returncode, 33, result.stdout + result.stderr)
        self.assertIn('durable server privacy fixture', result.stderr)

    def test_tool_bootstrap_installs_pinned_scanner_inside_project(self):
        cache = self.root / 'module-cache'
        classifier = cache / 'github.com/google/licenseclassifier@v0.0.0-20260218193730-3cfbab2d0e0d'
        (classifier / 'licenses').mkdir(parents=True)
        self.env['FIXTURE_MODULE_CACHE'] = str(cache)
        self.tool('go', 'printf "%s\\n" "${GOBIN:-}" "$@" >> "$GATE_ARGS_PATH"; '
                  'if [[ "$1" == env ]]; then echo "$FIXTURE_MODULE_CACHE"; fi; '
                  'if [[ "$1" == install && "$2" == *license_serializer* ]]; then '
                  'printf "#!/bin/bash\\nexit 0\\n" > "$GOBIN/license_serializer"; '
                  'chmod +x "$GOBIN/license_serializer"; fi')
        result = self.run_gate('bootstrap.sh', '--tools-only')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = (self.root / 'args').read_text().splitlines()
        self.assertEqual(args[0], str(self.root / '.tools/bin'))
        self.assertIn('golang.org/x/vuln/cmd/govulncheck@v1.8.0', args)
        self.assertIn('github.com/google/osv-scanner/v2/cmd/osv-scanner@v2.5.1', args)
        self.assertIn('github.com/zricethezav/gitleaks/v8@v8.30.1', args)
        self.assertIn('github.com/google/licenseclassifier/tools/license_serializer@v0.0.0-20260218193730-3cfbab2d0e0d', args)
        self.assertIn('./tools/identify_license', args)

    def test_tool_bootstrap_propagates_install_failure(self):
        self.tool('go', 'echo "scanner install fixture" >&2; exit 37')
        result = self.run_gate('bootstrap.sh', '--tools-only')
        self.assertEqual(result.returncode, 37, result.stdout + result.stderr)
        self.assertIn('scanner install fixture', result.stderr)

    def test_vulnerability_findings_are_not_suppressed(self):
        self.tool('govulncheck', 'echo "vulnerability fixture" >&2; exit 19')
        result = self.run_gate('vuln_check.sh')
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertIn('vulnerability fixture', result.stderr)

    def test_missing_scanner_is_not_replaced_with_vet(self):
        self.tool('go', 'echo "unexpected vet" > "$GATE_ARGS_PATH"')
        result = self.run_gate('vuln_check.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.root / 'args').exists())

    def test_secret_scanner_missing_fails_closed(self):
        result = self.run_gate('secret_check.sh')
        self.assertEqual(result.returncode, 127, result.stderr)

    def test_secret_findings_and_scanner_errors_propagate_redacted(self):
        self.tool('gitleaks', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"; '
                  'echo "scanner fixture finding" >&2; exit 19')
        result = self.run_gate('secret_check.sh')
        self.assertEqual(result.returncode, 19, result.stderr)
        args = (self.root / 'args').read_text().splitlines()
        self.assertIn('--redact=100', args)
        self.assertIn('--ignore-gitleaks-allow', args)
        self.assertIn('--staged', args)

    def test_secret_scanner_checks_index_and_untracked_working_content(self):
        (self.root / 'example.txt').write_text('snapshot fixture marker')
        self.tool('git', 'printf "example.txt\\0"')
        self.tool('gitleaks', 'printf "%s\\n" "$@" >> "$GATE_ARGS_PATH"; '
                  'if [[ "$1" == dir ]]; then '
                  'grep -q "snapshot fixture marker" "$2/example.txt"; fi')
        result = self.run_gate('secret_check.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.root / 'args').read_text().splitlines()
        self.assertIn('git', args)
        self.assertIn('dir', args)

    def test_missing_flutter_cannot_pass_full_dart_suite(self):
        self.tool('dart', 'exit 0')
        result = self.run_gate('dart_test.sh')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('flutter', (result.stdout + result.stderr).lower())

    def test_dependency_failure_preserves_diagnostics(self):
        self.tool('dart', 'echo "dependency resolution fixture" >&2; exit 31')
        self.tool('flutter', 'exit 0')
        result = self.run_gate('dart_test.sh')
        self.assertEqual(result.returncode, 31, result.stdout + result.stderr)
        self.assertIn('dependency resolution fixture', result.stdout + result.stderr)

    def test_contract_profile_explicitly_separates_real_model_acceptance(self):
        self.tool('dart', 'exit 0')
        self.tool('flutter', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"')
        result = self.run_gate('dart_test.sh', '--contracts-only')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('--exclude-tags=model_acceptance',
                      (self.root / 'args').read_text().splitlines())

    def test_full_profile_never_excludes_model_acceptance(self):
        self.tool('dart', 'exit 0')
        self.tool('flutter', 'printf "%s\\n" "$@" > "$GATE_ARGS_PATH"')
        result = self.run_gate('dart_test.sh')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.root / 'args').read_text().splitlines(), ['test'])

    def test_test_gate_requires_reviewed_dependency_resolutions(self):
        for tool in ['dart', 'flutter']:
            self.tool(tool, 'printf "%s\\n" "$@" >> "$GATE_ARGS_PATH"')
        result = self.run_gate('dart_test.sh', '--contracts-only')
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.root / 'args').read_text().splitlines()
        self.assertEqual(args.count('--enforce-lockfile'), 5)

    def test_outcome_tool_test_and_fixture_drift_fail_full_gate(self):
        self.tool('flutter', 'exit 0')
        for failure in ['test', 'check']:
            with self.subTest(failure=failure):
                self.tool('dart', 'if [[ "$PWD" == */tools ]]; then '
                          + ('if [[ "$1" == test ]]; then exit 41; fi; '
                             if failure == 'test' else
                             'if [[ "$*" == *--check* ]]; then exit 42; fi; ')
                          + 'fi; exit 0')
                result = self.run_gate('dart_test.sh', '--contracts-only')
                self.assertEqual(result.returncode, 41 if failure == 'test' else 42,
                                 result.stdout + result.stderr)

    def test_make_rejects_empty_or_unrecognized_suite_selectors(self):
        for selector in ['DART_TEST_TARGET', 'NATIVE_TEST_TARGET']:
            for value in ['', 'help', 'dart.test dart.contracts']:
                with self.subTest(selector=selector, value=value):
                    result = subprocess.run(
                        ['make', '--file', str(ROOT / 'Makefile'), 'help',
                         f'{selector}={value}'], cwd=self.root, env=self.env,
                        capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0, result.stdout)

    def test_contract_command_is_not_suppressed_by_a_same_named_file(self):
        (self.root / 'native.contracts').touch()
        result = subprocess.run(
            ['make', '--file', str(ROOT / 'Makefile'), '-n', 'native.contracts'],
            cwd=self.root, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('scripts/native_test.sh --contracts-only', result.stdout)


if __name__ == '__main__':
    unittest.main()

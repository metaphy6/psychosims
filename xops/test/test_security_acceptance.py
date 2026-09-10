"""Real scanner acceptance. Requires the project-pinned security tools."""
import json
import hashlib
from pathlib import Path
import random
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class SecretAcceptanceTests(unittest.TestCase):
    def test_public_certificate_hash_and_reconciliation_ids_stay_narrow(self):
        scanner = ROOT / '.tools/bin/gitleaks'
        with tempfile.TemporaryDirectory(prefix='certificate-secret-policy-', dir='/tmp/agent-runs') as tmp:
            root = Path(tmp)
            certificate = root / 'test_fixtures/outcomes/trusted_catalog_v1.json'
            certificate.parent.mkdir(parents=True)
            certificate.write_bytes((ROOT / 'test_fixtures/outcomes/trusted_catalog_v1.json').read_bytes())
            for name in ['testdata/reconciliation.json', 'wire_test.go']:
                target = root / 'server/internal/server' / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / 'server/internal/server' / name).read_bytes())
            base = [str(scanner), 'dir', str(root), '--redact=100', '--no-banner',
                    '--config', str(ROOT / '.gitleaks.toml'), '--ignore-gitleaks-allow',
                    '--gitleaks-ignore-path', '/dev/null']
            result = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            outside = root / 'outside_certificate.json'
            certificate.rename(outside)
            result = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            outside.rename(certificate)
            # A new opaque 64-digit value in the same artifact is still a finding.
            value = json.loads(certificate.read_text())
            value['api_key'] = hashlib.sha256(b'public planted scanner sentinel').hexdigest()
            certificate.write_text(json.dumps(value))
            result = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

    def test_real_scanner_rejects_a_planted_key_even_in_an_allowlisted_file(self):
        scanner = ROOT / '.tools/bin/gitleaks'
        self.assertTrue(scanner.is_file(), 'Run scripts/bootstrap.sh --tools-only')
        run_dir = Path('/tmp/agent-runs')
        run_dir.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='secret-acceptance-', dir=run_dir) as temp:
            root = Path(temp)
            file = root / 'test_fixtures/receipts/sample_receipt.json'
            file.parent.mkdir(parents=True)
            # Synthetic format-matching data, never issued by a credential provider.
            rng = random.Random(4409)
            synthetic = 'AK' + 'IA' + ''.join(rng.choices('ABCDEFGHIJKLMNOPQRSTUVWXYZ234567', k=16))
            file.write_text(json.dumps({'access_key': synthetic}))
            report = root / 'result.json'
            command = [str(scanner), 'dir', str(root), '--redact=100',
                       '--no-banner', '--config', str(ROOT / '.gitleaks.toml'),
                       '--ignore-gitleaks-allow', '--gitleaks-ignore-path', '/dev/null',
                       '--report-format=json', '--report-path', str(report)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)

            findings = json.loads(report.read_text())
            self.assertTrue(any(item['RuleID'] == 'aws-access-token' for item in findings))
            self.assertNotIn(synthetic, report.read_text() + result.stdout + result.stderr)

    def test_public_fixture_ids_and_assessment_prose_are_narrow_exceptions(self):
        scanner = ROOT / '.tools/bin/gitleaks'
        self.assertTrue(scanner.is_file(), 'Run scripts/bootstrap.sh --tools-only')
        with tempfile.TemporaryDirectory(prefix='secret-policy-', dir='/tmp/agent-runs') as temp:
            root = Path(temp)
            file = root / 'test_fixtures/receipts/sample_receipt.json'
            file.parent.mkdir(parents=True)
            file.write_text(json.dumps({'idempotency_key': 'ledger-fixture-' + '001'}))
            base = [str(scanner), 'dir', str(root), '--redact=100', '--no-banner',
                    '--config', str(ROOT / '.gitleaks.toml'),
                    '--ignore-gitleaks-allow', '--gitleaks-ignore-path', '/dev/null']
            result = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            file.rename(root / 'outside_allowlist.json')
            result = subprocess.run(base, cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)


class DependencyAcceptanceTests(unittest.TestCase):
    def test_real_classifier_rejects_unknown_and_incompatible_licenses(self):
        from scripts.sbom import parse_licenses
        classifier = ROOT / '.tools/bin/identify_license'
        self.assertTrue(classifier.is_file(), 'Run scripts/bootstrap.sh --tools-only')
        with tempfile.TemporaryDirectory(prefix='license-acceptance-', dir='/tmp/agent-runs') as temporary:
            path = Path(temporary) / 'LICENSE'
            path.write_text('All rights reserved. Permission is not granted for any use.')
            result = subprocess.run([str(classifier), '-threshold', '0.9', str(path)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=30)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            for name in ['MIT', 'GPL-3.0']:
                path.write_bytes((ROOT / '.tools/licenseclassifier/licenses' / f'{name}.txt').read_bytes())
                result = subprocess.run([str(classifier), '-threshold', '0.9', str(path)],
                                        cwd=ROOT, text=True, capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if name == 'MIT':
                    self.assertEqual(parse_licenses(result.stdout, [path])[path]['ids'], ['MIT'])
                else:
                    with self.assertRaisesRegex(ValueError, 'policy'):
                        parse_licenses(result.stdout, [path])

    def test_real_scanner_rejects_known_vulnerable_dependency(self):
        # https://pkg.go.dev/vuln/GO-2021-0113 affects x/text before v0.3.7.
        # Scan metadata only: never install or execute the vulnerable version.
        scanner = ROOT / '.tools/bin/osv-scanner'
        self.assertTrue(scanner.is_file(), 'Run scripts/bootstrap.sh --tools-only')
        with tempfile.TemporaryDirectory(prefix='osv-acceptance-', dir='/tmp/agent-runs') as temporary:
            directory = Path(temporary)
            source, output = directory / 'osv-scanner-custom.json', directory / 'result.json'
            source.write_text(json.dumps({'results': [{'packages': [{'package': {
                'name': 'golang.org/x/text', 'ecosystem': 'Go', 'version': 'v0.3.6'}}]}]}))
            result = subprocess.run([str(scanner), 'scan', 'source', '--no-call-analysis=go',
                                     '--format=json', '--output-file', str(output), '-L', str(source)],
                                    cwd=ROOT, text=True, capture_output=True, timeout=300)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            report = json.loads(output.read_text())
            ids = {vulnerability['id'] for group in report['results']
                   for package in group['packages'] for vulnerability in package.get('vulnerabilities', [])}
            self.assertIn('GO-2021-0113', ids)


if __name__ == '__main__':
    unittest.main()

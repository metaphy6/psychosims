#!/usr/bin/env python3
"""Scan the reviewed inventory and verify that no requested package was dropped."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def packages_from_inventory(document):
    packages = []
    for component in document['components']:
        ref = component['bom-ref']
        package = {'name': component['name'], 'version': component['version']}
        if ref.startswith('pkg:pub/'):
            package['ecosystem'] = 'Pub'
        elif ref.startswith('pkg:golang/'):
            package['ecosystem'] = 'Go'
        elif ref.startswith('native:llama.cpp@'):
            package = {'name': 'llama.cpp', 'ecosystem': 'GIT', 'commit': component['version']}
        else:
            continue  # Own code, SDK notice inventories and model license texts have no package advisory identity.
        packages.append({'package': package})
    if not packages or not any(item['package'].get('commit') for item in packages):
        raise ValueError('dependency scan is missing package or native commit coverage')
    return packages


def identity(package):
    if package.get('commit'):
        return ('GIT', package['commit'])
    return (package.get('ecosystem'), package.get('name'), package.get('version'))


def verify_coverage(requested, result):
    expected = {identity(item['package']) for item in requested}
    received = {identity(item['package']) for group in result.get('results', [])
                for item in group.get('packages', [])}
    missing = expected - received
    if missing:
        raise ValueError(f'scanner dropped {len(missing)} requested packages: {sorted(missing)}')


def main():
    try:
        scanner = ROOT / '.tools/bin/osv-scanner'
        if not scanner.is_file():
            raise ValueError('osv-scanner missing; run scripts/bootstrap.sh --tools-only')
        document = json.loads((ROOT / 'docs/reports/dependency-inventory.cdx.json').read_text())
        packages = packages_from_inventory(document)
        run_dir = Path('/tmp/agent-runs')
        run_dir.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='dependency-scan-', dir=run_dir) as temporary:
            directory = Path(temporary)
            source, output = directory / 'osv-scanner-custom.json', directory / 'result.json'
            source.write_text(json.dumps({'results': [{'source': {'path': 'reviewed-inventory', 'type': 'sbom'},
                                                        'packages': packages}]}))
            result = subprocess.run([str(scanner), 'scan', 'source', '--no-call-analysis=go',
                                     '--all-vulns', '--format=json', '--all-packages',
                                     '--output-file', str(output), '-L', str(source)],
                                    cwd=ROOT, capture_output=True, text=True, timeout=300)
            if result.returncode:
                print(result.stdout + result.stderr, file=sys.stderr)
                if output.is_file():
                    print(output.read_text(), file=sys.stderr)
                return result.returncode
            if not output.is_file():
                raise ValueError('scanner omitted its result')
            report = json.loads(output.read_text())
            verify_coverage(packages, report)
            if any(item.get('vulnerabilities') for group in report.get('results', [])
                   for item in group.get('packages', [])):
                raise ValueError('scanner reported vulnerabilities with a successful exit')
            print(f'OSV checked {len(packages)} package/version or native commit identities; no known vulnerabilities.')
        return 0
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
        print(f'Dependency scan failed: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

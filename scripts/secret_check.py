#!/usr/bin/env python3
"""Scan both staged bytes and current tracked/unignored files without uploading."""
import os
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main():
    os.chdir(ROOT)
    local_tool = ROOT / '.tools/bin/gitleaks'
    scanner = str(local_tool) if local_tool.is_file() else shutil.which('gitleaks')
    if scanner is None:
        print('gitleaks is required; run scripts/bootstrap.sh --tools-only', file=sys.stderr)
        return 127
    run_dir = Path('/tmp/agent-runs')
    run_dir.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='secret-scan-', dir=run_dir) as temp:
        temp = Path(temp)
        empty_ignore = temp / 'empty-ignore'
        empty_ignore.touch()
        flags = ['--redact=100', '--no-banner', '--no-color', '--timeout=120',
                 '--ignore-gitleaks-allow', '--gitleaks-ignore-path', str(empty_ignore),
                 '--config', str(ROOT / '.gitleaks.toml')]
        def scan(arguments, report_name):
            report = temp / report_name
            result = subprocess.run([scanner, *arguments, *flags,
                                     '--report-format=json', '--report-path', str(report)])
            if result.returncode:
                if report.is_file():
                    for item in json.loads(report.read_text()):
                        # Never render Match or Secret, even from a redacted report.
                        print(f"{item.get('RuleID')}: {item.get('File')!r}:"
                              f"{item.get('StartLine')}", file=sys.stderr)
                raise subprocess.CalledProcessError(result.returncode, [scanner])
        # Index bytes can differ from the working file; scan them before copies.
        scan(['git', '--staged'], 'index.json')
        files = subprocess.run(['git', 'ls-files', '--cached', '--others',
                                '--exclude-standard', '-z'], check=True,
                               stdout=subprocess.PIPE).stdout
        snapshot = temp / 'worktree'
        snapshot.mkdir()
        for name in sorted(set(files.split(b'\0')) - {b''}):
            relative = Path(os.fsdecode(name))
            source = ROOT / relative
            if relative.is_absolute() or '..' in relative.parts:
                raise ValueError('Git returned an unsafe path')
            if source.is_symlink() or not source.resolve().is_relative_to(ROOT):
                raise ValueError(f'Secret scan refuses symbolic links: {relative}')
            if not source.exists() or source.is_dir():
                # Deleted working files were checked in the index above. A
                # gitlink is a separate pinned repository, not a source blob.
                continue
            if not source.is_file():
                raise ValueError(f'Secret scan requires regular files: {relative}')
            target = snapshot / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        scan(['dir', str(snapshot)], 'worktree.json')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
    except (OSError, ValueError) as error:
        print(f'Secret scan failed: {error}', file=sys.stderr)
        sys.exit(1)

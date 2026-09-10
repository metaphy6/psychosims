#!/usr/bin/env python3
"""Check product content against the canonical fictional-taxonomy registry."""
import json
import os
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
REGISTRY = Path('content/fictional_taxonomy.yaml')
MAX_FILE_BYTES = 2 * 1024 * 1024


def read_text(path):
    if path.is_symlink():
        raise ValueError(f'Content input is a symbolic link: {path}')
    with path.open('rb') as source:
        data = source.read(MAX_FILE_BYTES + 1)
    if len(data) > MAX_FILE_BYTES:
        raise ValueError(f'Content input exceeds scan budget: {path}')
    return data.decode('utf-8')


def patterns_from_registry(text):
    # The registry deliberately uses JSON-quoted scalar regexes, a YAML subset.
    # Reject unsupported syntax instead of silently ignoring a malformed rule.
    patterns = []
    active = False
    seen = False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if line == 'forbidden_patterns:':
            if seen:
                raise ValueError('Duplicate forbidden_patterns registry')
            active = seen = True
        elif active and line.startswith('  - '):
            value = json.loads(line[4:])
            if not isinstance(value, str) or not value or len(value) > 4096:
                raise ValueError('Invalid forbidden pattern')
            patterns.append(re.compile(value))
        elif active and line.startswith(' '):
            raise ValueError('Registry patterns must be JSON-quoted YAML scalars')
        elif active:
            active = False
    if not patterns or len(patterns) > 64:
        raise ValueError('Registry must contain 1-64 forbidden patterns')
    return patterns


def json_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from json_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from json_strings(child)


def main():
    os.chdir(ROOT)
    paths = []
    for name in ['content', 'test_fixtures']:
        directory = Path(name)
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError(f'Missing directory or symbolic link: {directory}')
        def discovery_error(error):
            raise error
        for parent, dirs, files in os.walk(directory, onerror=discovery_error):
            for name in sorted(dirs + files):
                path = Path(parent) / name
                if path.is_symlink():
                    raise ValueError(f'Content input is a symbolic link: {path}')
                if name in files:
                    if not path.is_file():
                        raise ValueError(f'Content input is not a regular file: {path}')
                    paths.append(path)
    patterns = patterns_from_registry(read_text(REGISTRY))
    failures = []
    for path in sorted(paths):
        if path == REGISTRY:
            continue
        text = read_text(path)
        values = [text]
        if path.suffix == '.json':
            try:
                values.extend(json_strings(json.loads(text)))
            except json.JSONDecodeError:
                # Negative parser fixtures remain scanable as text; the loader
                # separately rejects malformed JSON before product use.
                pass
        if any(pattern.search(value) for value in values for pattern in patterns):
            failures.append(str(path))
    for path in failures:
        print(f'Forbidden taxonomy pattern in {path}', file=sys.stderr)
    if failures:
        return 1
    print(f'Content integrity passed: {len(paths) - 1} files, {len(patterns)} rules')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, re.error, RecursionError) as error:
        print(f'Content integrity failed: {error}', file=sys.stderr)
        sys.exit(1)

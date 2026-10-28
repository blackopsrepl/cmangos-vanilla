#!/usr/bin/env python3
"""Check the source distribution boundary, not the legal status of dependencies."""

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ROOT_FILES = {
    '.dockerignore', '.env.example', '.gitattributes', '.gitignore',
    'AGENTS.md', 'CONTRIBUTING.md', 'Dockerfile.cmangos',
    'Dockerfile.hermesproxy', 'LICENSE', 'README.md',
    'docker-compose.yml', 'docker-compose.linux.yml', 'versions.lock',
}
TEXT_DIRECTORIES = {'config', 'docker', 'docs', 'scripts'}
MASCOT = 'docs/assets/cmangos-vanilla-mascots.png'
FORBIDDEN_SUFFIXES = {
    '.sql', '.gz', '.zip', '.7z', '.rar', '.tar', '.bz2', '.xz',
    '.mpq', '.dbc', '.db2', '.adt', '.wdt', '.wmo', '.m2', '.blp',
    '.map', '.vmap', '.vmtree', '.vmtile', '.mmap', '.mmtile',
    '.exe', '.dll', '.lib', '.bin', '.cr', '.key', '.db', '.sqlite',
}


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])


def check(entries):
    failures = []
    for mode, oid, path in sorted(entries):
        if mode not in {'100644', '100755'}:
            failures.append(f'{path}: non-regular file mode {mode}')
            continue
        if path not in ROOT_FILES and path.split('/')[0] not in TEXT_DIRECTORIES:
            failures.append(f'{path}: outside the source distribution allowlist')
            continue
        if Path(path).suffix.lower() in FORBIDDEN_SUFFIXES:
            failures.append(f'{path}: bundled data, archive, or executable format')
            continue
        content = git('cat-file', 'blob', oid)
        if path == MASCOT:
            if not content.startswith(b'\x89PNG\r\n\x1a\n'):
                failures.append(f'{path}: expected PNG artwork')
        else:
            try:
                content.decode('utf-8')
                if b'\0' in content:
                    raise ValueError('embedded NUL')
            except (UnicodeError, ValueError):
                failures.append(f'{path}: binary content in a text-only path')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true',
                        help='also inspect every tree reachable from every local ref')
    args = parser.parse_args()
    entries = set()
    for record in git('ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        header, path = record.split(b'\t', 1)
        mode, oid, stage = header.decode().split()
        if stage != '0':
            sys.exit('Distribution check failed: unresolved index entries')
        entries.add((mode, oid, path.decode('utf-8')))
    if not entries:
        sys.exit('Distribution check failed: empty index')
    commits = git('rev-list', '--all').decode().splitlines() if args.history else []
    for commit in commits:
        for record in git('ls-tree', '-r', '-z', commit).split(b'\0'):
            if not record:
                continue
            header, path = record.split(b'\t', 1)
            mode, kind, oid = header.decode().split()
            if kind != 'blob':
                sys.exit('Distribution check failed: submodule or non-blob object')
            entries.add((mode, oid, path.decode('utf-8')))
    failures = check(entries)
    if failures:
        print('Distribution check failed:', file=sys.stderr)
        for failure in failures:
            print(f' - {failure}', file=sys.stderr)
        return 1
    print(f'Distribution check passed: {len(entries)} unique file versions; '
          f'{len(commits)} reachable commits inspected.')
    print('This checks bundled file boundaries, not copyright clearance or local images.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

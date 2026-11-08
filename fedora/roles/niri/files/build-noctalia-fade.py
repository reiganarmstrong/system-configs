#!/usr/bin/env python3
"""Rebuild Fedora's signed Noctalia SRPM with scoped Graphite patches."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_id(patch, selection_patch, test_patch):
    inputs = f'{digest(patch)}:{digest(selection_patch)}:{digest(test_patch)}:{digest(Path(__file__))}'
    return hashlib.sha256(inputs.encode()).hexdigest()[:12]


def patched_spec(text, release):
    """Keep Fedora's dependencies, prep, tests and installed file inventory."""
    if len(re.findall(r'^Source\d*\s*:', text, re.M)) != 1 or re.search(r'^Source999[789]:', text, re.M):
        raise ValueError('Fedora source declarations changed; review the spec before rebuilding')
    text, count = re.subn(r'^Release:.*$', 'Release:        ' + release, text, flags=re.M)
    if count != 1:
        raise ValueError('Expected exactly one Fedora Release field')
    text, count = re.subn(
        r'^(Source\d*\s*:.*)$',
        r'\1\nSource9999:      graphite-panel-fade.patch\nSource9998:      graphite-quiet-selection.patch\nSource9997:      graphite-upower-test-lifetime.patch',
        text, flags=re.M
    )
    if count != 1:
        raise ValueError('Expected exactly one upstream source archive')
    text, count = re.subn(
        r'^(%autosetup[^\n]*)$',
        r'\1\n\n# No fuzzy or three-way patch application: changed context stops the build.\n'
        r'git apply --check %{SOURCE9999}\ngit apply %{SOURCE9999}\n'
        r"grep -Fq 'm_sceneRoot->setOpacity(m_detachedRevealProgress);' src/shell/panel/panel_manager.cpp\n"
        r'git apply --check %{SOURCE9998}\ngit apply %{SOURCE9998}\n'
        r"grep -Fq 'inline Button::ButtonPalette quietPalette(' src/shell/panel/panel_button_style.h\n"
        r'git apply --check %{SOURCE9997}\ngit apply %{SOURCE9997}\n'
        r"grep -Fq 'deferredCalls.emplace_back([this]' tests/upower_charge_limit_integration_test.cpp",
        text, flags=re.M,
    )
    if count != 1:
        raise ValueError('Fedora prep changed; expected one %autosetup command')
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--patch', type=Path, required=True)
    parser.add_argument('--selection-patch', type=Path, required=True)
    parser.add_argument('--test-patch', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--jobs', type=int, default=2)
    args = parser.parse_args()
    if not 1 <= args.jobs <= 16:
        parser.error('--jobs must be between 1 and 16')
    source, patch = args.source.resolve(), args.patch.resolve()
    selection_patch = args.selection_patch.resolve()
    test_patch = args.test_patch.resolve()
    env = dict(os.environ, LC_ALL='C')
    signature = subprocess.run(
        ['rpmkeys', '--checksig', str(source)], capture_output=True, text=True, env=env, check=True
    ).stdout
    if 'digests signatures OK' not in signature:
        raise ValueError('Source RPM must have a valid signature trusted by this Fedora installation')
    metadata = subprocess.check_output(
        ['rpm', '-qp', '--qf', '%{NAME}\n%{VERSION}\n%{RELEASE}\n', str(source)], text=True, env=env
    ).splitlines()
    if len(metadata) != 3 or metadata[0] != 'noctalia' or any('/' in x for x in metadata):
        raise ValueError('Expected a Fedora noctalia source RPM')
    _, version, release = metadata
    if '.graphite.' in release:
        raise ValueError('Use an original Fedora source RPM, not a previous local rebuild')
    identity = build_id(patch, selection_patch, test_patch)
    local_release = release + '.graphite.' + identity
    work = args.cache.resolve() / f'{version}-{release}-{identity}'
    work.mkdir(parents=True, exist_ok=True)
    manifest = work / 'build.json'
    if manifest.exists():
        cached = json.loads(manifest.read_text())
        artifact = Path(cached['rpm'])
        if cached['source_sha256'] == digest(source) and artifact.is_file() and digest(artifact) == cached['rpm_sha256']:
            print(json.dumps(dict(cached, changed=False)))
            return
    top = work / 'rpmbuild'
    if top.exists():
        shutil.rmtree(top)
    for directory in ['BUILD', 'BUILDROOT', 'RPMS', 'SOURCES', 'SPECS', 'SRPMS']:
        (top / directory).mkdir(parents=True)
    log_path = work / 'build.log'
    with log_path.open('w') as log:
        def run(argv):
            result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT, env=env)
            if result.returncode:
                raise RuntimeError(f'{argv[0]} failed; see {log_path}')

        run(['rpm', '-i', '--define', '_topdir ' + str(top), str(source)])
        specs = list((top / 'SPECS').glob('*.spec'))
        if len(specs) != 1:
            raise ValueError('Expected one source RPM spec')
        spec = specs[0]
        spec.write_text(patched_spec(spec.read_text(), local_release))
        shutil.copyfile(patch, top / 'SOURCES/graphite-panel-fade.patch')
        shutil.copyfile(selection_patch, top / 'SOURCES/graphite-quiet-selection.patch')
        shutil.copyfile(test_patch, top / 'SOURCES/graphite-upower-test-lifetime.patch')
        run([
            'rpmbuild', '-ba', '--define', '_topdir ' + str(top),
            '--define', f'_smp_build_ncpus {args.jobs}',
            '--define', f'_smp_mflags -j{args.jobs}', str(spec),
        ])
    architecture = subprocess.check_output(['rpm', '--eval', '%{_arch}'], text=True).strip()
    artifact = top / f'RPMS/{architecture}/noctalia-{version}-{local_release}.{architecture}.rpm'
    if not artifact.is_file():
        raise RuntimeError(f'Missing expected package: {artifact}')
    result = dict(
        build_id=identity, version=version, release=local_release, rpm=str(artifact),
        source_sha256=digest(source), patch_sha256=digest(patch),
        selection_patch_sha256=digest(selection_patch),
        test_patch_sha256=digest(test_patch),
        rpm_sha256=digest(artifact), log=str(log_path),
    )
    manifest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(result, changed=True)))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)

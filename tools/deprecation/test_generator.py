#!/usr/bin/env python3
"""Negative controls for generate_registry.py: each case breaks one thing in a scratch copy of the schema (or of
removed.json), asserts the edit really applied, and expects the run to fail with that problem's own message.
Run from anywhere:  python3 tools/deprecation/test_generator.py"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
GEN = os.path.join(HERE, 'generate_registry.py')
FAILED = []


def scratch():
    tmp = tempfile.mkdtemp()
    for d in ('core', 'extended', 'specialty'):
        shutil.copytree(os.path.join(ROOT, d), os.path.join(tmp, d))
    for f in os.listdir(ROOT):
        if f.endswith('.xsd'):
            shutil.copy(os.path.join(ROOT, f), tmp)
    shutil.copytree(os.path.join(ROOT, 'deprecated'), os.path.join(tmp, 'deprecated'))
    shutil.copy(os.path.join(HERE, 'removed.json'), os.path.join(tmp, 'removed.json'))
    return tmp


def run(tmp, *extra):
    p = subprocess.run([sys.executable, GEN, '--schema-root', tmp, '--removed', os.path.join(tmp, 'removed.json'),
                        '--quiet', '--baseline-repo', ROOT, *extra], capture_output=True, text=True)
    return p.returncode, p.stderr + p.stdout


def edit(path, pattern, repl, flags=0):
    s = open(path, encoding='utf-8').read()
    new, n = re.subn(pattern, repl, s, count=1, flags=flags)
    assert n == 1, 'edit did not apply: %s in %s' % (pattern, path)
    open(path, 'w', encoding='utf-8').write(new)


def expect(name, code, out, want_code, needle):
    ok = code == want_code and (needle is None or needle in out)
    print('%s  %s' % ('PASS' if ok else 'FAIL', name))
    if not ok:
        FAILED.append(name)
        print('      exit %s; wanted %s containing %r; got:\n%s' % (code, want_code, needle, out[:600]))


def main():
    tmp = scratch()
    code, out = run(tmp, '--audit-baseline', '3.0.0')
    expect('control: untouched copy passes, baseline audit included', code, out, 0, None)

    t = scratch()
    edit(os.path.join(t, 'core/Core.xsd'), r'<diggs:deprecated since="3\.1\.0"\s+replacedBy="diggs:plunge"/>',
         '<diggs:deprecated since="3.1.0"/>')
    c, o = run(t)
    expect('marker with neither replacedBy nor note', c, o, 1, 'marker has neither replacedBy nor note')

    t = scratch()
    edit(os.path.join(t, 'core/Core.xsd'), r'replacedBy="diggs:plunge"', 'replacedBy="diggs:noSuchElement"')
    c, o = run(t)
    expect('replacedBy names no declaration', c, o, 1, 'replacedBy diggs:noSuchElement names no declaration')

    t = scratch()
    edit(os.path.join(t, 'core/Core.xsd'), r'<diggs:deprecated since="3\.1\.0"\s+replacedBy="diggs:plunge"/>', '')
    c, o = run(t)
    expect('deprecation stated in text with no marker', c, o, 1, 'deprecation stated in text but no <diggs:deprecated> marker')

    t = scratch()
    edit(os.path.join(t, 'core/Core.xsd'), r'since="3\.1\.0"(\s+replacedBy="diggs:plunge")', r'since="3.1"\1')
    c, o = run(t)
    expect('since is not a release version', c, o, 1, 'is not a release version')

    t = scratch()
    edit(os.path.join(t, 'core/Core.xsd'), r'<documentation>\s*DEPRECATED\. Use plunge', '<documentation>Use plunge')
    c, o = run(t)
    expect('documentation does not open DEPRECATED.', c, o, 1, 'documentation does not open "DEPRECATED. "')

    t = scratch()
    r = json.load(open(os.path.join(t, 'removed.json')))
    r['removed'].append({'kind': 'type', 'name': 'diggs:LabCompactionTestType', 'removedIn': '3.1.0',
                         'note': 'x', 'migration': 'manual'})
    json.dump(r, open(os.path.join(t, 'removed.json'), 'w'))
    c, o = run(t)
    expect('removed name still declared live', c, o, 1, 'still declared in the schema')

    t = scratch()
    r = json.load(open(os.path.join(t, 'removed.json')))
    r['removed'].append(dict(r['removed'][0]))
    json.dump(r, open(os.path.join(t, 'removed.json'), 'w'))
    c, o = run(t)
    expect('duplicate key', c, o, 1, 'duplicate key')

    t = scratch()
    r = json.load(open(os.path.join(t, 'removed.json')))
    gone = r['removed'].pop(0)
    json.dump(r, open(os.path.join(t, 'removed.json'), 'w'))
    c, o = run(t)
    expect('without the audit, a dropped removed entry is not noticed', c, o, 0, None)
    c, o = run(t, '--audit-baseline', '3.0.0')
    expect('audit: released name gone but not listed', c, o, 1, 'was released, is no longer declared and is not in removed.json')

    t = scratch()
    r = json.load(open(os.path.join(t, 'removed.json')))
    r['removed'].append({'kind': 'type', 'name': 'diggs:NeverReleasedType', 'removedIn': '3.1.0',
                         'note': 'x', 'migration': 'none'})
    json.dump(r, open(os.path.join(t, 'removed.json'), 'w'))
    c, o = run(t, '--audit-baseline', '3.0.0')
    expect('audit: removed entry the baseline never had', c, o, 1, 'which baseline 3.0.0 never declared')

    t = scratch()
    c, o = run(t)
    expect('generate into a scratch copy', c, o, 0, 'written')
    c, o = run(t, '--check')
    expect('--check passes on current files', c, o, 0, 'current')
    edit(os.path.join(t, 'deprecated/DeprecationRegistry.json'), r'"schemaVersion": "[^"]+"', '"schemaVersion": "9.9.9"')
    c, o = run(t, '--check')
    expect('--check fails on a stale file', c, o, 1, 'STALE')

    print('\n%d failed' % len(FAILED) if FAILED else '\nall passed')
    return 1 if FAILED else 0


if __name__ == '__main__':
    sys.exit(main())

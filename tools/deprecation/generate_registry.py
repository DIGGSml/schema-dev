#!/usr/bin/env python3
"""Generate the DIGGS deprecation registry from the schema.

Reads
  * every <diggs:deprecated since=".." replacedBy=".." note=".."/> marker in the <appinfo> of a
    DIGGS schema file (core/, extended/, specialty/ and the masters)  -> entries with status "deprecated"
  * tools/deprecation/removed.json (hand kept: a removed name has no declaration left to carry a marker)
                                                                       -> entries with status "removed"
and writes
  deprecated/DeprecationRegistry.xml   (validates against deprecated/DeprecationRegistry.xsd)
  deprecated/DeprecationRegistry.json  (the same content, for tools that prefer JSON)

Usage
  generate_registry.py                      regenerate both files
  generate_registry.py --check              write nothing; exit 1 if the files on disk are stale
  generate_registry.py --audit-baseline 3.0.0 [--baseline-repo DIR]
                                            also fail if a global name that existed in the baseline git tag is
                                            neither declared now nor listed in removed.json, or if a removed
                                            entry names something the baseline never had
Standard library only. The run fails (exit 1, every problem listed) on: a marker without since or without
replacedBy/note, a marker whose documentation does not open "DEPRECATED.", deprecation stated in text with no
marker, a replacedBy that names no declaration, a "removed" name still declared in the schema, a duplicate key.
"""
import argparse
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape, quoteattr

XS = 'http://www.w3.org/2001/XMLSchema'
DIGGS = 'http://diggsml.org/schemas/3'
DR = 'http://diggsml.org/schemas/3/deprecation'
PREFIXES = {
    'diggs': DIGGS,
    'glr': 'http://www.opengis.net/gml/3.3/lr',
    'gml': 'http://www.opengis.net/gml/3.2',
    'xlink': 'http://www.w3.org/1999/xlink',
}
SCHEMA_DIRS = ('', 'core', 'extended', 'specialty')
EXCLUDE_FILES = {'DeletedElements.xsd'}          # only ever present in release trees before it was retired
KINDS = ('element', 'branchRef', 'type', 'attribute', 'enumValue', 'compoundBranch')
MIGRATIONS = ('rename', 'convert', 'manual', 'none')
VERSION_RE = re.compile(r'^\d+\.\d+\.\d+$')
REMOVED_FIELDS = {'kind', 'name', 'removedIn', 'replacedBy', 'note', 'migration', 'file', 'deprecatedSince'}


def q(tag):
    return '{%s}%s' % (XS, tag)


def local(tag):
    return tag.split('}')[-1]


def text(e):
    return ' '.join(''.join(e.itertext()).split()) if e is not None else ''


def diggs_name(v):
    """local part of a diggs:-prefixed QName, else None (unprefixed names in these files are XML Schema built-ins)."""
    return v.split(':', 1)[1] if v and v.startswith('diggs:') else None


class Doc:
    def __init__(self, rel, path):
        self.rel = rel
        self.root = ET.parse(path).getroot()
        self.parent = {c: p for p in self.root.iter() for c in p}


def load_docs(tree):
    docs = []
    for d in SCHEMA_DIRS:
        base = os.path.join(tree, d)
        if not os.path.isdir(base):
            continue
        for f in sorted(os.listdir(base)):
            if f.endswith('.xsd') and f not in EXCLUDE_FILES:
                doc = Doc(os.path.join(d, f) if d else f, os.path.join(base, f))
                if doc.root.get('targetNamespace') == DIGGS:
                    docs.append(doc)
    return docs


def global_names(docs):
    """{(kind, name)} of every global element / type / attribute declared in the DIGGS namespace."""
    out = set()
    for doc in docs:
        for e in doc.root:
            n = e.get('name')
            if n and e.tag in (q('element'), q('attribute')):
                out.add((local(e.tag), n))
            elif n and e.tag in (q('complexType'), q('simpleType')):
                out.add(('type', n))
    return out


class Index:
    """Type derivation and element declarations, for deriving the instance XPath of a marked item."""

    def __init__(self, docs):
        self.docs = docs
        self.types = {}
        self.global_elements = {}
        self.reverse = {}
        self.elements = []                 # (name, node, abstract)
        self.declared = set()              # every declared local name, for resolving replacedBy
        for doc in docs:
            for e in doc.root:
                if e.get('name') and e.tag in (q('complexType'), q('simpleType')):
                    self.types[e.get('name')] = e
                elif e.get('name') and e.tag == q('element'):
                    self.global_elements[e.get('name')] = e
        for name, t in self.types.items():
            for base in self.bases(t):
                self.reverse.setdefault(base, set()).add(name)
        for doc in docs:
            for e in doc.root.iter():
                if e.tag in (q('element'), q('attribute'), q('complexType'), q('simpleType')) and e.get('name'):
                    self.declared.add(e.get('name'))
                if e.tag == q('element') and e.get('name'):
                    self.elements.append((e.get('name'), e, e.get('abstract') == 'true'))

    @staticmethod
    def bases(t):
        out = []
        if t.tag == q('simpleType'):
            for r in t.findall(q('restriction')):
                out.append(diggs_name(r.get('base')))
            for u in t.findall(q('union')):
                out += [diggs_name(m) for m in (u.get('memberTypes') or '').split()]
            for li in t.findall(q('list')):
                out.append(diggs_name(li.get('itemType')))
        else:
            for c in t:
                if c.tag in (q('complexContent'), q('simpleContent')):
                    for d in c:
                        if d.tag in (q('extension'), q('restriction')):
                            out.append(diggs_name(d.get('base')))
        return [b for b in out if b]

    def closure(self, name):
        seen, todo = set(), [name]
        while todo:
            n = todo.pop()
            if n not in seen:
                seen.add(n)
                todo += self.reverse.get(n, ())
        return seen

    def declared_types(self, el, depth=0):
        """diggs type names an element declaration is typed by (type attribute, an inline extension's base, or the
        head of its substitution group when it states neither)."""
        t = diggs_name(el.get('type'))
        if t:
            return [t]
        inline = el.find(q('complexType'))
        if inline is not None:
            return self.bases(inline)
        head = diggs_name(el.get('substitutionGroup'))
        if head and head in self.global_elements and depth < 10:
            return self.declared_types(self.global_elements[head], depth + 1)
        return []

    def element_names_of(self, type_names):
        return {n for n, el, abstract in self.elements
                if not abstract and any(t in type_names for t in self.declared_types(el))}


def host_info(doc, node):
    """(global ancestor, nearest enclosing named element node or None)."""
    inner = None
    p = doc.parent.get(node)
    while p is not None and doc.parent.get(p) is not None:
        if inner is None and p.tag == q('element') and p.get('name'):
            inner = p
        node_p = p
        p = doc.parent.get(p)
        if p is doc.root:
            return node_p, inner
    return doc.root, inner


def parent_names(doc, node, idx):
    """Names of the instance elements that can contain the marked particle."""
    g, inner = host_info(doc, node)
    if g is doc.root:
        return set()
    if inner is not None:
        return {inner.get('name')}
    if g.tag == q('element'):
        return {g.get('name')}
    return idx.element_names_of(idx.closure(g.get('name')))


def global_element_xpath(idx, decl):
    """A global element and a local element of the same name are the same qualified name in an instance. Where a
    live local element shares the name, qualify the path by the parents that reference the global element."""
    name = decl.get('name')
    if not any(n == name and e is not decl for n, e, a in idx.elements):
        return '//diggs:%s' % name, True
    parents, exact = set(), True
    for doc in idx.docs:
        for r in doc.root.iter(q('element')):
            if r.get('ref') == 'diggs:' + name:
                parents |= parent_names(doc, r, idx)
                exact = exact and is_exact(doc, r, idx, {name})
    if not parents:
        return '//diggs:%s' % name, False
    return ' | '.join('//diggs:%s/diggs:%s' % (p, name) for p in sorted(parents)), exact


def particle_set(idx, tname, depth=0):
    """Names of every element and attribute (attributes as @name) a named type can contain, through its bases;
    nested anonymous types are included, which errs towards reporting a collision."""
    t = idx.types.get(tname)
    out = set()
    if t is None or depth > 20:
        return out
    for e in t.iter():
        if e.tag == q('element'):
            out.add(e.get('name') or (e.get('ref') or '').split(':')[-1])
        elif e.tag == q('attribute'):
            out.add('@' + (e.get('name') or (e.get('ref') or '').split(':')[-1]))
    for b in idx.bases(t):
        out |= particle_set(idx, b, depth + 1)
    return out


def is_exact(doc, node, idx, children):
    """False when a same-named parent element is declared elsewhere with a type that can also contain the same
    child: the name-based instance XPath then matches live, valid content as well."""
    g, inner = host_info(doc, node)
    own = inner if inner is not None else (g if g.tag == q('element') else None)
    clos = set() if own is not None else idx.closure(g.get('name'))
    for p in parent_names(doc, node, idx):
        for n, e, abstract in idx.elements:
            if n != p or e is own:
                continue
            types = idx.declared_types(e)
            if own is None and any(t in clos for t in types):
                continue
            if not types:
                names = {x.get('name') or (x.get('ref') or '').split(':')[-1] for x in e.iter(q('element'))}
                names |= {'@' + x.get('name', '') for x in e.iter(q('attribute'))}
            else:
                names = set().union(*[particle_set(idx, t) for t in types])
            if children is None or names & children:
                return False
    return True


def particle_names(branch):
    out = []
    for c in branch:
        if c.tag == q('element'):
            out.append(c.get('ref') or ('diggs:' + c.get('name')))
    return out


def build_deprecated(docs, idx, problems):
    entries = []
    for doc in docs:
        for ann in doc.root.iter(q('annotation')):
            decl = doc.parent[ann]
            if decl is doc.root:
                continue
            markers = list(ann.iter('{%s}deprecated' % DIGGS))
            ai = ' '.join(text(a) for a in ann.findall(q('appinfo')))
            docs_ = ann.findall(q('documentation'))
            first_doc = text(docs_[0]) if docs_ else ''
            where = '%s %s' % (doc.rel, local(decl.tag) + ' ' + (decl.get('name') or decl.get('ref') or decl.get('value') or ''))
            stated = 'DEPRECATED' in ai.upper() or any(text(d).lower().startswith('deprecated') for d in docs_[:1])
            if not markers:
                if stated:
                    problems.append('%s: deprecation stated in text but no <diggs:deprecated> marker' % where)
                continue
            if len(markers) != 1:
                problems.append('%s: %d markers (expected 1)' % (where, len(markers)))
                continue
            m = markers[0]
            extra = set(m.attrib) - {'since', 'replacedBy', 'note'}
            since, rb, note = m.get('since'), m.get('replacedBy', ''), m.get('note', '')
            if extra:
                problems.append('%s: unknown marker attributes %s' % (where, sorted(extra)))
            if not since or not VERSION_RE.match(since):
                problems.append('%s: marker since=%r is not a release version' % (where, since))
            if not (rb or note):
                problems.append('%s: marker has neither replacedBy nor note' % where)
            if not first_doc.startswith('DEPRECATED. '):
                problems.append('%s: documentation does not open "DEPRECATED. " (%r)' % (where, first_doc[:50]))
            if rb.startswith('diggs:') and rb.split(':', 1)[1] not in idx.declared:
                problems.append('%s: replacedBy %s names no declaration' % (where, rb))

            g, innode = host_info(doc, decl)
            inner = innode.get('name') if innode is not None else None
            host = g.get('name') if g is not doc.root and g is not decl else ''
            tag = decl.tag
            e = dict(status='deprecated', file=doc.rel, since=since, replacedBy=rb, note=note, xpath='', exact=True)
            if tag == q('element') and doc.parent[decl] is doc.root:
                e.update(kind='element', name='diggs:' + decl.get('name'), host='')
                e['xpath'], e['exact'] = global_element_xpath(idx, decl)
            elif tag == q('element'):
                kind = 'branchRef' if decl.get('ref') else 'element'
                name = decl.get('ref') or 'diggs:' + decl.get('name')
                e.update(kind=kind, name=name, host=inner or host)
                e['xpath'] = ' | '.join('//diggs:%s/%s' % (p, name) for p in sorted(parent_names(doc, decl, idx)))
                e['exact'] = is_exact(doc, decl, idx, {name.split(':')[-1]})
            elif tag in (q('complexType'), q('simpleType')):
                e.update(kind='type', name='diggs:' + decl.get('name'), host='')
            elif tag == q('attribute'):
                e.update(kind='attribute', name=decl.get('name'), host=inner or host)
                e['xpath'] = ' | '.join('//diggs:%s/@%s' % (p, decl.get('name')) for p in sorted(parent_names(doc, decl, idx)))
                e['exact'] = is_exact(doc, decl, idx, {'@' + decl.get('name')})
            elif tag == q('enumeration'):
                tnames = idx.closure(host)
                # a complexType with simple content extends the enumeration: include it as a holder too
                holders = idx.element_names_of(tnames)
                val = decl.get('value')
                e.update(kind='enumValue', name=val, host=host)
                e['xpath'] = ' | '.join("//diggs:%s[. = %s]" % (p, quote_xpath(val)) for p in sorted(holders))
                e['exact'] = all(is_exact_holder(idx, p, tnames) for p in holders)
            elif tag in (q('sequence'), q('choice')):
                same = [c for c in doc.parent[decl] if c.tag == tag]
                e.update(kind='compoundBranch', name='%s[%d]' % (local(tag), same.index(decl) + 1), host=host)
                kids = particle_names(decl)
                cond = ' or '.join(k for k in kids) if kids else ''
                if kids:
                    e['xpath'] = ' | '.join('//diggs:%s[%s]' % (p, cond) for p in sorted(idx.element_names_of(idx.closure(host))))
                    e['exact'] = is_exact(doc, decl, idx, {k.split(':')[-1] for k in kids})
            else:
                problems.append('%s: marker in an unsupported context' % where)
                continue
            e['host'] = ('diggs:' + e['host']) if e['host'] else ''
            e['migration'] = derive_migration(doc, decl, e, idx)
            e['_loc'] = where
            entries.append(e)
    return entries


def is_exact_holder(idx, holder, type_names):
    """An enumeration value is matched on the element that holds it: inexact if the same element name is
    declared anywhere with a type outside the enumeration's closure (it may hold the same text legitimately)."""
    return not any(n == holder and not any(t in type_names for t in idx.declared_types(e))
                   for n, e, a in idx.elements)


def quote_xpath(v):
    return "'%s'" % v if "'" not in v else '"%s"' % v


def derive_migration(doc, decl, e, idx):
    """rename = the replacement is a declaration of the same name-kind with the identical type in the same host;
    convert = replaced, but not by a drop-in; manual = no single replacement."""
    rb, note = e['replacedBy'], e['note']
    if not rb:
        return 'manual'
    if note:
        return 'convert'
    if e['kind'] in ('element', 'branchRef') and rb.startswith('diggs:'):
        want = rb.split(':', 1)[1]
        g, _ = host_info(doc, decl)
        scope = g if (g is not doc.root and g is not decl) else None
        cands = [c for c in (scope.iter(q('element')) if scope is not None else idx.global_elements.values())
                 if c.get('name') == want]
        have = (decl.get('type') or decl.get('ref'))
        if cands and have and any((c.get('type') or c.get('ref')) == have for c in cands):
            return 'rename'
    return 'convert'


def load_removed(path, live, problems):
    data = json.load(open(path, encoding='utf-8'))
    out = []
    for r in data['removed']:
        bad = set(r) - REMOVED_FIELDS
        miss = {'kind', 'name', 'removedIn', 'migration'} - set(r)
        where = 'removed.json %s %s' % (r.get('kind'), r.get('name'))
        if bad or miss:
            problems.append('%s: unknown fields %s, missing fields %s' % (where, sorted(bad), sorted(miss)))
            continue
        if r['kind'] not in KINDS or r['migration'] not in MIGRATIONS or not VERSION_RE.match(r['removedIn']):
            problems.append('%s: bad kind/migration/removedIn' % where)
            continue
        if not (r.get('replacedBy') or r.get('note')) and r['migration'] != 'none':
            problems.append('%s: migration %s needs replacedBy or note' % (where, r['migration']))
        local_name = r['name'].split(':', 1)[1] if r['name'].startswith('diggs:') else r['name']
        if (r['kind'], local_name) in live:
            problems.append('%s: still declared in the schema - a name that is live is not removed' % where)
        e = dict(status='removed', kind=r['kind'], name=r['name'], host='', file=r.get('file', ''),
                 since=r.get('deprecatedSince', ''), removedIn=r['removedIn'], replacedBy=r.get('replacedBy', ''),
                 note=r.get('note', ''), migration=r['migration'], _loc=where)
        e['xpath'] = '//%s' % r['name'] if r['kind'] == 'element' else ''
        out.append(e)
    return out


def key_of(e):
    return '%s:%s%s' % (e['kind'], (e['host'] + '/') if e['host'] else '', e['name'])


def render_xml(entries, version):
    L = ['<?xml version="1.0" encoding="UTF-8"?>',
         '<!-- Generated by tools/deprecation/generate_registry.py from the diggs:deprecated markers in the schema',
         '     and tools/deprecation/removed.json. Do not edit; edit the schema or removed.json and regenerate. -->',
         '<dr:DeprecationRegistry xmlns:dr="%s" schemaVersion="%s">' % (DR, version)]
    for p, u in PREFIXES.items():
        L.append('    <dr:namespace prefix="%s" uri="%s"/>' % (p, u))
    for e in entries:
        attrs = [('key', key_of(e)), ('status', e['status']), ('kind', e['kind']), ('name', e['name'])]
        for k, f in (('host', 'host'), ('file', 'file'), ('since', 'since'), ('removedIn', 'removedIn'),
                     ('replacedBy', 'replacedBy'), ('migration', 'migration')):
            if e.get(f):
                attrs.append((k, e[f]))
        head = '    <dr:entry ' + ' '.join('%s=%s' % (k, quoteattr(v)) for k, v in attrs)
        kids = []
        if e['note']:
            kids.append('        <dr:note>%s</dr:note>' % escape(e['note']))
        if e['xpath']:
            kids.append('        <dr:instanceXPath%s>%s</dr:instanceXPath>'
                        % ('' if e.get('exact', True) else ' exact="false"', escape(e['xpath'])))
        if kids:
            L += [head + '>'] + kids + ['    </dr:entry>']
        else:
            L.append(head + '/>')
    L.append('</dr:DeprecationRegistry>')
    return '\n'.join(L) + '\n'


def render_json(entries, version):
    out = []
    for e in entries:
        d = {'key': key_of(e), 'status': e['status'], 'kind': e['kind'], 'name': e['name']}
        for k in ('host', 'file', 'since', 'removedIn', 'replacedBy', 'migration', 'note'):
            if e.get(k):
                d[k] = e[k]
        d['instanceXPath'] = e['xpath']
        if e['xpath'] and not e.get('exact', True):
            d['instanceXPathExact'] = False
        out.append(d)
    return json.dumps({'schemaVersion': version, 'namespaces': PREFIXES, 'entries': out},
                      indent=2, ensure_ascii=False) + '\n'


def baseline_names(root, tag):
    raw = subprocess.run(['git', '-C', root, 'archive', tag], check=True, capture_output=True).stdout
    with tempfile.TemporaryDirectory() as tmp:
        tarfile.open(fileobj=io.BytesIO(raw)).extractall(tmp, filter='data')
        return global_names(load_docs(tmp))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--schema-root', default=os.path.abspath(os.path.join(here, '..', '..')))
    ap.add_argument('--removed', default=os.path.join(here, 'removed.json'))
    ap.add_argument('--out-dir')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--audit-baseline', metavar='TAG')
    ap.add_argument('--baseline-repo', help='git repository holding the baseline tag (default: the schema root)')
    ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args()
    root = a.schema_root
    out_dir = a.out_dir or os.path.join(root, 'deprecated')

    problems = []
    docs = load_docs(root)
    idx = Index(docs)
    live = global_names(docs)
    version = next(d.root.get('version') for d in docs if d.rel == 'Diggs.xsd')
    dep = build_deprecated(docs, idx, problems)
    rem = load_removed(a.removed, live, problems)
    entries = dep + rem

    seen = {}
    for e in entries:
        k = key_of(e)
        if k in seen:
            problems.append('duplicate key %s (%s and %s)' % (k, seen[k], e['_loc']))
        seen[k] = e['_loc']
    for e in rem:
        if e['replacedBy'].startswith('diggs:') and e['replacedBy'].split(':', 1)[1] not in idx.declared:
            problems.append('%s: replacedBy %s names no declaration' % (e['_loc'], e['replacedBy']))

    if a.audit_baseline:
        try:
            base = baseline_names(a.baseline_repo or root, a.audit_baseline)
        except subprocess.CalledProcessError as err:
            print('FAILED - cannot read baseline %s: %s' % (a.audit_baseline, err.stderr.decode().strip()),
                  file=sys.stderr)
            return 1
        listed = {(e['kind'] if e['kind'] != 'element' else 'element', e['name'].split(':', 1)[-1]) for e in rem if not e['host']}
        for kind, n in sorted(base - live - listed):
            problems.append('baseline %s: %s %s was released, is no longer declared and is not in removed.json'
                            % (a.audit_baseline, kind, n))
        for kind, n in sorted(listed - base):
            problems.append('removed.json lists %s %s, which baseline %s never declared' % (kind, n, a.audit_baseline))

    n_dep, n_rem = len(dep), len(rem)
    kinds = {}
    for e in entries:
        kinds.setdefault((e['status'], e['kind']), 0)
        kinds[(e['status'], e['kind'])] += 1
    if not a.quiet:
        print('entries: %d (deprecated %d, removed %d)' % (len(entries), n_dep, n_rem))
        print('by status/kind: ' + ', '.join('%s/%s %d' % (s, k, c) for (s, k), c in sorted(kinds.items())))
        print('migration: ' + ', '.join('%s %d' % (m, sum(1 for e in entries if e['migration'] == m)) for m in MIGRATIONS))
        print('instance XPath not exact (a live use shares the path): %d' % sum(1 for e in entries if e['xpath'] and not e.get('exact', True)))
        print('entries with an instance XPath: %d; without: %d' % (sum(1 for e in entries if e['xpath']),
                                                                    sum(1 for e in entries if not e['xpath'])))
        for e in entries:
            print('  %-10s %s' % (e['status'], key_of(e)))
    if problems:
        print('\nFAILED - %d problem(s):' % len(problems), file=sys.stderr)
        for p in problems:
            print('  ' + p, file=sys.stderr)
        return 1

    outputs = {'DeprecationRegistry.xml': render_xml(entries, version),
               'DeprecationRegistry.json': render_json(entries, version)}
    stale = []
    for fn, content in outputs.items():
        path = os.path.join(out_dir, fn)
        on_disk = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        if on_disk != content:
            stale.append(fn)
            if not a.check:
                os.makedirs(out_dir, exist_ok=True)
                open(path, 'w', encoding='utf-8', newline='\n').write(content)
    if a.check:
        if stale:
            print('STALE: %s - run generate_registry.py' % ', '.join(stale), file=sys.stderr)
            return 1
        print('registry files are current')
    else:
        print('written: %s' % (', '.join(stale) if stale else 'nothing (already current)'))
    return 0


if __name__ == '__main__':
    sys.exit(main())

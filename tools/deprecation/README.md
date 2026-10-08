# Deprecation registry tools

Builds `deprecated/DeprecationRegistry.xml` and `.json` - the list of everything in the DIGGS schema that is
deprecated or has been removed - and checks that the list is complete and consistent. This folder is
development tooling and is excluded from releases (`.gitattributes`); the registry files are released.

    python3 tools/deprecation/generate_registry.py                          regenerate both files
    python3 tools/deprecation/generate_registry.py --check                  exit 1 if the files are stale
    python3 tools/deprecation/generate_registry.py --audit-baseline 3.0.0   also compare with a released tag
    python3 tools/deprecation/test_generator.py                             negative controls for the checks

Standard library only (Python 3.12+).

## Deprecating something

Put the marker in the `appinfo` of the declaration (or of the `ref`, branch, attribute or enumeration value),
and open its documentation with `DEPRECATED. Use ...`:

    <annotation>
        <appinfo>
            <diggs:deprecated since="3.1.0" replacedBy="diggs:accreditingBody" note="..."/>
        </appinfo>
        <documentation>DEPRECATED. Use accreditingBody. Identification of the accrediting body.</documentation>
    </annotation>

* `since` is the first release whose schema treats the item as deprecated.
* `replacedBy` is the single element, attribute or type that takes its place; leave it out where no single name
  does (it must not suggest a rename that would be wrong). `note` is free text; at least one of the two is required.
* Then regenerate and commit the registry with the schema change.

## Removing something

Delete the declaration, then add an entry to `removed.json` **if a release had it** (a name created and deleted
within one development cycle is not recorded). Run with `--audit-baseline <last release tag>`: it fails if a
released global name is neither declared nor listed, and if a listed name was never released. The run also fails
if a listed name is still declared.

At a major release, delete every deprecated declaration, move its entry from the markers into `removed.json`
(`removedIn` = that release), and regenerate.

## What the generator checks

A marker with no `since` or no `replacedBy`/`note`; documentation that does not open `DEPRECATED. `; deprecation
stated in text with no marker; a `replacedBy` that names nothing; a removed name still declared; a duplicate key.

`instanceXPath` is built from element names. Where a live use of the same names would also match, the entry is
marked `exact="false"`: a match is then a candidate, not a certainty.

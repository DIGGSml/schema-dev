DIGGS Version 3 is a new production release of DIGGS, with many fixes and enhancements to the schema as compared to v. 2.6. This release is **NOT** backward compatible with v. 2.6 in that structural changes have been made to a number of elements. However, the vast majority of these changes affect elements that are little used at present or lock into schema best-practice encodings that are already in practice so that many v 2.6 instances will likely validate under v 3.

A detailed compatibility report along with a summary table of new elements and types will be posted here shortly.

Version 3 improves encodings used for soil descriptions, measurements involving time-series data , and many other improvements and additions. Many of the changes resulted from user feedback and experiences from the 2025 Hackathon. There has been significant changes "under the hood", involving the development of more logical schema modules. As part of this release, a subset of the full DIGGS schema focusing on borehole and sounding observations and basic testing can be cleanly accessed to reduce complexity, Users are encouraged to use v. 3 schemas for developing future instances and to strongly consider converting v. 2.6 instances to v. 3.

Please post any issues with this release to: [https://github.com/DIGGSml/schema-dev/issues](https://github.com/DIGGSml/schema-dev/issues)

## Resources
### schemaLocation for this version
[https://diggsml.org/schemas/ 3.0.0/Diggs.xsd ](https://diggsml.org/schemas/3.0.0/Diggs.xsd) (full schema)
https://diggsml.org/schemas/3.0.0/DiggsCore.xsd (core schema - supports basic borehole and sounding exploration data only)

### XML Namespace
 http://diggsml.org/schemas/3
 
 ### Online schema documentation (this specific version)
 https://diggsml.org/docs/3.0.0

### Example instances
https://github.com/DIGGSml/diggs-examples/tree/master/3.x%20Example%20Instances

## What's Changed
Complete rearchitecting of the schema modules was performed for this release: This change facilitates profiling, documentation and maintenance of the schema but does not in itself affect instance files.

**Full Changelog**: https://github.com/DIGGSml/schema-dev/compare/2.6...3.0.0

## Summary of Changes

*******Coming********

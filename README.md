# 2.5.b Development Branch

This is a branch for proposed nominal object/property updates to 
2.5.a. Schema changes in this branch are designed such that 
instance documents validated against the 2.5.a schema will also be valid under 2.5.b. This
includes:

1. Addition of optional properties to existing objects
1. Addition of optional objects (eg. new test procedures)
1. Modifications/additions to object/property annototions
1. Additions of terms to enumerated lists

**Note:** instance documents that use new 2.5.b elements or list
items will **NOT** validate under 2.5.a.

##Changes/addtions under 2.5.b

1. Now incorporates unit symbology from WITSML 2.0 schema. This adds a singificant number of new quantity classes and units symbols to DIGGS.
    1. **Note:** need to check for deprecated symbols in WITSML that have been removed in 2.0 and add these back in DIGGS namespace lists for compatibility.
    1. Most WITSML 1.3 measure types have moved to a new namespace (eml). A few WITSML 1.3 types used in DIGGS 2.5.a still remain in the WITSML namespace.
1. In Geotechnical schema:
    1. added estimatedWaterDepth property to StaticConePenetrationTest test procedure object
    1. added PorePressureDissipationTest prodedure object (initial proposal) for review.
    1. added PointLoadTest procedure object for review.
    
---


The DIGGS project involves development of a GML (XML-based) geospatial standard schema for the transfer of geotechnical and geoenvironmental data within an organization or between multiple organizations.  DIGGS can work with existing software, hardware, databases and data storage facilities to easily transfer and share your data. 

![alt text](https://www.geoinstitute.org/sites/default/files/inline-images/DIGGS%20use%20case.png "DIGGSml Use Case Diagram")

Once implemented by your organization, the DIGGS data transfer standard will help meet your needs for information and data asset management.  It is anticipated that DIGGS will save state and federal agencies, and other public and private organizations millions of dollars.  Savings will be realized through a combination of avoided drilling and laboratory testing costs, and efficiencies afforded by the availability of geotechnical data for multiple projects in a standard format. 

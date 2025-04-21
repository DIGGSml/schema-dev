<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:saxon="http://saxon.sf.net/"
    xmlns:diggs="http://diggsml.org/schema-dev"
    xmlns:gml="http://www.opengis.net/gml/3.2" 
    xmlns:g3.3="http://www.opengis.net/gml/3.3/ce"
    xmlns:glr="http://www.opengis.net/gml/3.3/lr" 
    xmlns:glrov="http://www.opengis.net/gml/3.3/lrov"
    queryBinding="xslt2">
    
    <title>DIGGS CodeSpace Validation</title>
    
    <!-- XSLT variables and functions for source element validation -->
    <xsl:variable name="root" select="/*"/>
    
    <xsl:function name="saxon:context-match" as="xs:boolean">
        <xsl:param name="current" as="node()"/>
        <xsl:param name="xpath" as="xs:string"/>
        
        <!-- Create namespace context for evaluation -->
        <xsl:variable name="nsMap" as="map(xs:string, xs:string)">
            <xsl:map>
                <xsl:map-entry key="'diggs'" select="'http://diggsml.org/schema-dev'"/>
                <xsl:map-entry key="'gml'" select="'http://www.opengis.net/gml/3.2'"/>
                <xsl:map-entry key="'g3.3'" select="'http://www.opengis.net/gml/3.3/ce'"/>
                <xsl:map-entry key="'glr'" select="'http://www.opengis.net/gml/3.3/lr'"/>
                <xsl:map-entry key="'glrov'" select="'http://www.opengis.net/gml/3.3/lrov'"/>
                <xsl:map-entry key="'xlink'" select="'http://www.w3.org/1999/xlink'"/>
            </xsl:map>
        </xsl:variable>
        
        <!-- Try to evaluate the XPath against the document with namespaces -->
        <xsl:variable name="result" select="saxon:evaluate($xpath, $root, $nsMap)"/>
        
        <!-- Check if the current node is in the result -->
        <xsl:value-of select="exists($result[. is $current])"/>
    </xsl:function>  
    
    <!-- Updated URL regex to handle both absolute and relative paths -->
    <let name="urlRegex" value="'^(https?://([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(:[0-9]+)?(/[^\s#]*)?|file:///[^\s#]*?|[^:]+)#[^\s]+$'"/>
    
    <!-- Default phase - reordered patterns to run context-validation before name-validation -->
    <phase id="all">
        <active pattern="url-format"/>
        <active pattern="document-availability"/>
        <active pattern="dictionary-validation"/>
        <active pattern="definition-validation"/>
        <active pattern="source-element-validation"/>
        <active pattern="name-validation"/>
    </phase>
    
    <!-- Step 1: URL format check -->
    <pattern id="url-format">
        <rule context="//*[@codeSpace]">
            <report test="not(matches(@codeSpace, $urlRegex))" 
                id="invalid-url" 
                role="information">
                INFO: The the value of <name/> cannot be validated. If codeSpace attribute "<value-of select="@codeSpace"/>" references an authority, be sure that the value "<value-of select="."/>" is a valid term controlled by "<value-of select="@codeSpace"/>"
            </report>
        </rule>
    </pattern>
    
    <!-- Step 2: Document availability check with enhanced URL handling -->
    <pattern id="document-availability">
        <rule context="//*[@codeSpace][matches(@codeSpace, $urlRegex)]">
            <let name="rawUrl" value="replace(@codeSpace, '(^.*)(#.*)$', '$1')"/>
            <!-- Handle relative paths -->
            <let name="dictionaryUrl" value="
                if (starts-with($rawUrl, 'http') or starts-with($rawUrl, 'file:///')) then
                $rawUrl
                else
                resolve-uri($rawUrl, base-uri(.))
                "/>
            
            <!-- Use try/catch to prevent fatal errors when doc is not available -->
            <let name="isDocAvailable" value="doc-available($dictionaryUrl)"/>
            
            <assert test="$isDocAvailable" 
                id="resource-not-available" 
                role="error">
                ERROR: The URL "<value-of select="$dictionaryUrl"/>" referenced in the codeSpace attribute could not be accessed.
            </assert>
        </rule>
    </pattern>
    
    <!-- Step 3: Dictionary validation with enhanced URL handling -->
    <pattern id="dictionary-validation">
        <rule context="//*[@codeSpace][matches(@codeSpace, $urlRegex)]">
            <let name="rawUrl" value="replace(@codeSpace, '(^.*)(#.*)$', '$1')"/>
            <!-- Handle relative paths -->
            <let name="dictionaryUrl" value="
                if (starts-with($rawUrl, 'http') or starts-with($rawUrl, 'file:///')) then
                $rawUrl
                else
                resolve-uri($rawUrl, base-uri(.))
                "/>
            
            <!-- Check document availability again -->
            <let name="isDocAvailable" value="doc-available($dictionaryUrl)"/>
            
            <!-- Only proceed if document is available -->
            <report test="$isDocAvailable and not(doc($dictionaryUrl)//*[local-name()='Dictionary'])" 
                id="not-dictionary" 
                role="error">
                ERROR: The resource at "<value-of select="$dictionaryUrl"/>" is not a valid Dictionary document.
            </report>
        </rule>
    </pattern>
    
    <!-- Step 4: Definition exists validation with enhanced URL handling -->
    <pattern id="definition-validation">
        <rule context="//*[@codeSpace][matches(@codeSpace, $urlRegex)]">
            <let name="rawUrl" value="replace(@codeSpace, '(^.*)(#.*)$', '$1')"/>
            <let name="fragmentId" value="replace(@codeSpace, '^.*#(.*)$', '$1')"/>
            
            <!-- Handle relative paths -->
            <let name="dictionaryUrl" value="
                if (starts-with($rawUrl, 'http') or starts-with($rawUrl, 'file:///')) then
                $rawUrl
                else
                resolve-uri($rawUrl, base-uri(.))
                "/>
            
            <!-- Check document availability -->
            <let name="isDocAvailable" value="doc-available($dictionaryUrl)"/>
            
            <!-- Check if it's a dictionary (only if available) -->
            <let name="isDictionary" value="
                if ($isDocAvailable) then
                    exists(doc($dictionaryUrl)//*[local-name()='Dictionary'])
                else 
                    false()
            "/>
            
            <!-- Only proceed if document is available and is a dictionary -->
            <report test="$isDocAvailable and $isDictionary and
                not(doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId])" 
                id="no-definition" 
                role="error">
                ERROR: No Definition with id="<value-of select="$fragmentId"/>" found in the dictionary at "<value-of select="$dictionaryUrl"/>".
            </report>
        </rule>
    </pattern>
    
    <!-- Step 5: Source element validation -->
    <pattern id="source-element-validation">
        <rule context="//*[@codeSpace][matches(@codeSpace, $urlRegex)]">
            <let name="rawUrl" value="replace(@codeSpace, '(^.*)(#.*)$', '$1')"/>
            <let name="fragmentId" value="replace(@codeSpace, '^.*#(.*)$', '$1')"/>
            
            <!-- Handle relative paths -->
            <let name="dictionaryUrl" value="
                if (starts-with($rawUrl, 'http') or starts-with($rawUrl, 'file:///')) then
                $rawUrl
                else
                resolve-uri($rawUrl, base-uri(.))
                "/>
            
            <!-- Check document availability -->
            <let name="isDocAvailable" value="doc-available($dictionaryUrl)"/>
            
            <!-- Check if it's a dictionary (only if available) -->
            <let name="isDictionary" value="
                if ($isDocAvailable) then
                    exists(doc($dictionaryUrl)//*[local-name()='Dictionary'])
                else 
                    false()
            "/>
            
            <!-- Check if definition exists (only if it's a dictionary) -->
            <let name="hasDefinition" value="
                if ($isDictionary) then
                    exists(doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId])
                else
                    false()
            "/>
            
            <!-- Get all sourceElementXpath values from the definition (only if definition exists) -->
            <let name="sourceElementXpaths" value="
                if ($hasDefinition) then
                    doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId]//*[local-name()='sourceElementXpath']
                else
                    ()
            "/>
            
            <!-- Create a string representation of the current path -->
            <let name="currentElementPath" value="
                string-join(
                for $a in ancestor-or-self::* 
                return concat('/', local-name($a)), 
                ''
                )
                "/>
            
            <!-- Process source XPaths to remove namespace prefixes for comparison -->
            <let name="processedXpaths" value="
                for $xpath in $sourceElementXpaths
                return replace($xpath, '/([a-zA-Z0-9]+):', '/')
                "/>
            
            <!-- Check if current path matches any allowed path pattern -->
            <let name="contextValid" value="
                if (count($sourceElementXpaths) = 0) then
                true()
                else (
                some $processedXpath in $processedXpaths
                satisfies (
                if (starts-with($processedXpath, '//')) then
                contains($currentElementPath, substring-after($processedXpath, '//'))
                else
                ends-with($currentElementPath, $processedXpath)
                )
                )
                "/>
            
            <!-- Create readable path for error reporting -->
            <let name="readablePath" value="string-join(for $seg in ancestor-or-self::* return concat('/', name($seg)), '')"/>
            
            <!-- Only check context if all prerequisites are met -->
            <assert test="not($isDocAvailable and $isDictionary and $hasDefinition and count($sourceElementXpaths) > 0) or
                $contextValid" 
                id="context-mismatch" 
                role="error">
                ERROR: The element <name/> with value "<value-of select="."/>" references a definition that is not allowed at this location in the XML instance. 
                Current path: "<value-of select="$readablePath"/>" 
                Allowed paths: "<value-of select="string-join($sourceElementXpaths, ', ')"/>".
            </assert>
        </rule>
    </pattern>
    
    <!-- Step 6: Name validation with dependency on context being valid -->
    <pattern id="name-validation">
        <rule context="//*[@codeSpace][matches(@codeSpace, $urlRegex)]">
            <let name="rawUrl" value="replace(@codeSpace, '(^.*)(#.*)$', '$1')"/>
            <let name="fragmentId" value="replace(@codeSpace, '^.*#(.*)$', '$1')"/>
            
            <!-- Handle relative paths -->
            <let name="dictionaryUrl" value="
                if (starts-with($rawUrl, 'http') or starts-with($rawUrl, 'file:///')) then
                $rawUrl
                else
                resolve-uri($rawUrl, base-uri(.))
                "/>
            
            <!-- Check document availability -->
            <let name="isDocAvailable" value="doc-available($dictionaryUrl)"/>
            
            <!-- Check if it's a dictionary (only if available) -->
            <let name="isDictionary" value="
                if ($isDocAvailable) then
                    exists(doc($dictionaryUrl)//*[local-name()='Dictionary'])
                else 
                    false()
            "/>
            
            <!-- Check if definition exists (only if it's a dictionary) -->
            <let name="hasDefinition" value="
                if ($isDictionary) then
                    exists(doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId])
                else
                    false()
            "/>
            
            <!-- Get all sourceElementXpath values from the definition (only if definition exists) -->
            <let name="sourceElementXpaths" value="
                if ($hasDefinition) then
                    doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId]//*[local-name()='sourceElementXpath']
                else
                    ()
            "/>
            
            <!-- Check if context is valid (same logic as in context-validation pattern) -->
            <let name="currentElementPath" value="
                string-join(
                for $a in ancestor-or-self::* 
                return concat('/', local-name($a)), 
                ''
                )
                "/>
            
            <let name="processedXpaths" value="
                for $xpath in $sourceElementXpaths
                return replace($xpath, '/([a-zA-Z0-9]+):', '/')
                "/>
            
            <let name="contextValid" value="
                if (count($sourceElementXpaths) = 0) then
                true()
                else (
                some $processedXpath in $processedXpaths
                satisfies (
                if (starts-with($processedXpath, '//')) then
                contains($currentElementPath, substring-after($processedXpath, '//'))
                else
                ends-with($currentElementPath, $processedXpath)
                )
                )
                "/>
            
            <!-- Only proceed with name validation if context is valid -->
            <let name="canProceedWithNameValidation" value="
                not($isDocAvailable and $isDictionary and $hasDefinition and count($sourceElementXpaths) > 0) or
                $contextValid
                "/>
            
            <!-- Get all name elements from the definition (only if we can proceed) -->
            <let name="definitionNames" value="
                if ($canProceedWithNameValidation and $hasDefinition) then
                    doc($dictionaryUrl)//*[local-name()='Definition'][@*[local-name()='id']=$fragmentId]//*[local-name()='name']
                else
                    ()
            "/>
            
            <!-- If we can proceed, get normalized value of current element -->
            <let name="currentValue" value="lower-case(normalize-space(.))"/>
            
            <!-- Function to check if the current value matches any of the definition names -->
            <let name="matchesAnyName" value="
                some $name in $definitionNames 
                satisfies lower-case(normalize-space($name)) = $currentValue
                "/>
            
            <!-- Only check name if context is valid, document is available, is dictionary, and definition exists -->
            <report test="$canProceedWithNameValidation and 
                $isDocAvailable and 
                $isDictionary and
                $hasDefinition and
                count($definitionNames) > 0 and
                not($matchesAnyName)" 
                id="name-mismatch" 
                role="warning">
                WARNING: The value "<value-of select="."/>" in element <name/> is a name that does not match 
                "<value-of select="string-join(for $name in $definitionNames return normalize-space($name), ', ')"/>" 
                in the referenced Definition. Be sure that "<value-of select="."/>" is a synonymous name.
            </report>
        </rule>
    </pattern>
</schema>
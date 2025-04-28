<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:saxon="http://saxon.sf.net/"
    xmlns:diggs="http://diggsml.org/schema-dev" xmlns:gml="http://www.opengis.net/gml/3.2"
    xmlns:g3.3="http://www.opengis.net/gml/3.3/ce" xmlns:glr="http://www.opengis.net/gml/3.3/lr"
    xmlns:glrov="http://www.opengis.net/gml/3.3/lrov" queryBinding="xslt2">

    <title>DIGGS CodeSpace Validation</title>

    <!-- Updated URL regex to handle both absolute and relative paths -->
    <let name="urlRegex"
        value="'^(https?://([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}(:[0-9]+)?(/[^\s#]*)?|file:///[^\s#]*?|[^:]+)#[^\s]+$'"/>

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
            <report test="not(matches(@codeSpace, $urlRegex))" id="invalid-url" role="information">
                INFO: The the value of <name/> cannot be validated. If codeSpace attribute
                    "<value-of select="@codeSpace"/>" references an authority, be sure that the
                value "<value-of select="."/>" is a valid term controlled by "<value-of
                    select="@codeSpace"/>" </report>
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

            <assert test="$isDocAvailable" id="resource-not-available" role="error"> ERROR: The URL
                    "<value-of select="$dictionaryUrl"/>" referenced in the codeSpace attribute
                could not be accessed. </assert>
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
            <report test="$isDocAvailable and not(doc($dictionaryUrl)/*[name() = 'gml:Dictionary'])"
                id="not-dictionary" role="warning"> WARNING: The resource at "<value-of
                    select="$dictionaryUrl"/>" is not a valid DIGGS dictionary. If this value is
                intended to reference an authority rather than a DIGGS dictionary, be sure that the
                value "<value-of select="."/>" is a valid term controlled by "<value-of
                    select="@codeSpace"/>" </report>
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
                        exists(doc($dictionaryUrl)//*[local-name() = 'Dictionary'])
                    else
                        false()
                    "/>

            <!-- Only proceed if document is available and is a dictionary -->
            <report test="
                    $isDocAvailable and $isDictionary and
                    not(doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId])"
                id="no-definition" role="error"> ERROR: No Definition with id="<value-of
                    select="$fragmentId"/>" found in the dictionary at "<value-of
                    select="$dictionaryUrl"/>". </report>
        </rule>
    </pattern>

    <!-- Step 5: Source element validation - SIMPLIFIED IMPLEMENTATION -->
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
                        exists(doc($dictionaryUrl)//*[local-name() = 'Dictionary'])
                    else
                        false()
                    "/>

            <!-- Check if definition exists (only if it's a dictionary) -->
            <let name="hasDefinition" value="
                    if ($isDictionary) then
                        exists(doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId])
                    else
                        false()
                    "/>

            <!-- Get all sourceElementXpath values from the definition (only if definition exists) -->
            <let name="sourceElementXpaths" value="
                    if ($hasDefinition) then
                        doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId]//*[local-name() = 'sourceElementXpath']
                    else
                        ()
                    "/>

            <!-- Create a full XPath to the current element for better matching -->
            <let name="currentElementPath" value="
                    string-join(
                    for $a in ancestor-or-self::*
                    return
                        concat('/',
                        if (namespace-uri($a) != '') then
                            concat(
                            if (namespace-uri($a) = 'http://diggsml.org/schema-dev') then
                                'diggs:'
                            else
                                if (namespace-uri($a) = 'http://www.opengis.net/gml/3.2') then
                                    'gml:'
                                else
                                    if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/ce') then
                                        'g3.3:'
                                    else
                                        if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/lr') then
                                            'glr:'
                                        else
                                            if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/lrov') then
                                                'glrov:'
                                            else
                                                '',
                            local-name($a)
                            )
                        else
                            local-name($a)
                        ),
                    ''
                    )
                    "/>

            <!-- Check if any xpath matches the current element path -->
            <let name="isPathMatched" value="false()"/>

            <let name="pathMatches" value="
                for $xpath in $sourceElementXpaths
                return
                let $pathParts := tokenize(substring-after($xpath, '//'), '//')
                return
                if (count($pathParts) = 1) then
                contains($currentElementPath, concat('/', $pathParts[1], '/'))
                or ends-with($currentElementPath, concat('/', $pathParts[1]))
                else if (count($pathParts) = 2) then
                (contains($currentElementPath, concat('/', $pathParts[1], '/'))
                or ends-with($currentElementPath, concat('/', $pathParts[1])))
                and
                (contains(substring-after($currentElementPath, concat('/', $pathParts[1], '/')), 
                concat('/', $pathParts[2], '/'))
                or ends-with(substring-after($currentElementPath, concat('/', $pathParts[1], '/')), 
                concat('/', $pathParts[2])))
                else
                false()
                "/>
            
            <let name="hasMatchingPath" value="
                count($sourceElementXpaths) = 0 or
                count(
                for $match in $pathMatches
                return if ($match) then true() else ()
                ) > 0
                "/>
            
            <let name="debugInfo" value="
                concat(
                'Current Path: ', $currentElementPath, 
                ', Source XPaths: ', string-join($sourceElementXpaths, ' | '),
                ', Path parts: ', 
                string-join(
                for $xpath in $sourceElementXpaths
                return concat(
                '[', $xpath, '] → [',
                string-join(
                for $part in tokenize(substring-after($xpath, '//'), '//')
                return $part,
                '][')
                , ']'
                ),
                '; '
                ),
                ', Matches: ', string-join(
                for $i in 1 to count($sourceElementXpaths)
                return concat(
                $sourceElementXpaths[$i], ': ',
                if ($pathMatches[$i]) then 'true' else 'false'
                ),
                '; '
                ),
                ', hasMatchingPath: ', if($hasMatchingPath) then 'true' else 'false',
                ', pathMatches: [', 
                string-join(
                for $match in $pathMatches 
                return if ($match) then 'true' else 'false', 
                ', '
                ),
                ']'
                )
                "/>            <!-- Create readable path for error reporting -->
            <let name="readablePath" value="$currentElementPath"/>

            <!-- Only check context if all prerequisites are met -->
            <assert test="
                    not($isDocAvailable and $isDictionary and $hasDefinition and count($sourceElementXpaths) > 0) or
                    $hasMatchingPath" id="context-mismatch" role="error"> ERROR: The
                element <name/> with value "<value-of select="."/>" references a definition that is
                not allowed at this location in the XML instance. Current path: "<value-of
                    select="$readablePath"/>" Allowed paths: "<value-of
                    select="string-join($sourceElementXpaths, ', ')"/>". 
                Debug: <value-of select="$debugInfo"/>
                
            </assert>
            <!-- Add this after your assert statement in the rule -->
            <report test="true()" id="debug-info" role="information"> DEBUG: <value-of
                    select="$debugInfo"/>
            </report>
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
                        exists(doc($dictionaryUrl)//*[local-name() = 'Dictionary'])
                    else
                        false()
                    "/>

            <!-- Check if definition exists (only if it's a dictionary) -->
            <let name="hasDefinition" value="
                    if ($isDictionary) then
                        exists(doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId])
                    else
                        false()
                    "/>

            <!-- Get all sourceElementXpath values from the definition (only if definition exists) -->
            <let name="sourceElementXpaths" value="
                    if ($hasDefinition) then
                        doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId]//*[local-name() = 'sourceElementXpath']
                    else
                        ()
                    "/>

            <!-- Create a full XPath to the current element for better matching -->
            <let name="currentElementPath" value="
                    string-join(
                    for $a in ancestor-or-self::*
                    return
                        concat('/',
                        if (namespace-uri($a) != '') then
                            concat(
                            if (namespace-uri($a) = 'http://diggsml.org/schema-dev') then
                                'diggs:'
                            else
                                if (namespace-uri($a) = 'http://www.opengis.net/gml/3.2') then
                                    'gml:'
                                else
                                    if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/ce') then
                                        'g3.3:'
                                    else
                                        if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/lr') then
                                            'glr:'
                                        else
                                            if (namespace-uri($a) = 'http://www.opengis.net/gml/3.3/lrov') then
                                                'glrov:'
                                            else
                                                '',
                            local-name($a)
                            )
                        else
                            local-name($a)
                        ),
                    ''
                    )
                    "/>

            <let name="hasMatchingPath" value="
                    count($sourceElementXpaths) = 0 or
                    count(
                    for $xpath in $sourceElementXpaths
                    return
                        if (contains($xpath, '//')) then
                            if ((starts-with($xpath, '//') or
                            contains($currentElementPath, substring-before($xpath, '//'))) and
                            (contains($currentElementPath, concat('/', substring-after($xpath, '//'))) or
                            ends-with($currentElementPath, concat('/', substring-after($xpath, '//'))))) then
                                true()
                            else
                                ()
                        else
                            if (ends-with($currentElementPath, $xpath)) then
                                true()
                            else
                                ()
                    ) > 0
                    "/>

            <let name="debugInfo" value="
                    concat('Current Path: ', $currentElementPath,
                    ', Source XPaths: ', string-join($sourceElementXpaths, ' | '),
                    ', hasMatchingPath: ', if ($hasMatchingPath) then
                        'true'
                    else
                        'false')
                    "/>

            <!-- Only proceed with name validation if context is valid -->
            <let name="canProceedWithNameValidation" value="
                    not($isDocAvailable and $isDictionary and $hasDefinition and count($sourceElementXpaths) > 0) or
                    $hasMatchingPath
                    "/>

            <!-- Get all name elements from the definition (only if we can proceed) -->
            <let name="definitionNames" value="
                    if ($canProceedWithNameValidation and $hasDefinition) then
                        doc($dictionaryUrl)//*[local-name() = 'Definition'][@*[local-name() = 'id'] = $fragmentId]//*[local-name() = 'name']
                    else
                        ()
                    "/>

            <!-- If we can proceed, get normalized value of current element -->
            <let name="currentValue" value="lower-case(normalize-space(.))"/>

            <!-- Check if current value matches any definition name -->
            <let name="hasNameMatch" value="
                    count($definitionNames) = 0 or
                    count(
                    for $name in $definitionNames
                    return
                        if (lower-case(normalize-space($name)) = $currentValue) then
                            true()
                        else
                            ()
                    ) > 0
                    "/>

            <!-- Only check name if context is valid, document is available, is dictionary, and definition exists -->
            <report test="
                    $canProceedWithNameValidation and
                    $isDocAvailable and
                    $isDictionary and
                    $hasDefinition and
                    count($definitionNames) > 0 and
                    not($hasNameMatch)" id="name-mismatch" role="warning"> WARNING: The
                value "<value-of select="."/>" in element <name/> is a name that does not match
                    "<value-of select="
                        string-join(for $name in $definitionNames
                        return
                            normalize-space($name), ', ')"/>" in the referenced
                Definition. Be sure that "<value-of select="."/>" is a synonymous name. Debug:
                    <value-of select="$debugInfo"/>
            </report>
        </rule>
    </pattern>
</schema>

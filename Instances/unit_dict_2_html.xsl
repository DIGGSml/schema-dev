<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:uom="http://www.energistics.org/energyml/data/uomv1">
    
    <xsl:output method="html" indent="yes" encoding="UTF-8"/>
    
    <xsl:template match="/">
        <html>
            <head>
                <title>Unit Dictionary</title>
                <style>
                    body {
                    font-family: Arial, sans-serif;
                    margin: 0;
                    padding: 0;
                    background-color: #FFEFD5; /* Light amber background */
                    }
                    .header-container {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 10px 20px;
                    }
                    .logo {
                    flex: 0 0 150px;
                    }
                    .title-container {
                    flex: 1;
                    text-align: center;
                    }
                    h1 {
                    margin: 0;
                    }
                    .search-row {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    padding: 20px;
                    gap: 20px;
                    }
                    #filterInput {
                    padding: 8px;
                    width: 500px;
                    font-size: 16px;
                    }
                    #rowCount {
                    font-weight: bold;
                    min-width: 200px;
                    }
                    table {
                    border-collapse: collapse;
                    width: 100%;
                    background-color: white;
                    }
                    .container {
                    background-color: white;
                    margin: 0 20px 20px 20px;
                    max-height: 70vh;
                    overflow-y: auto;
                    }
                    th, td {
                    border: 1px solid #ddd;
                    padding: 8px;
                    text-align: left;
                    }
                    th {
                    position: sticky;
                    top: 0;
                    background-color: #000000;
                    color: white;
                    font-weight: bold;
                    text-align: center;
                    vertical-align: middle;
                    z-index: 1;
                    padding: 10px 5px;
                    height: 40px;
                    }
                    /* Style for alternating quantity classes */
                    .quantity-class-even {
                    background-color: #f0f0f0; /* Light grey */
                    }
                    .quantity-class-odd {
                    background-color: #ffffff; /* White */
                    }
                    /* Row border styling */
                    tr {
                    border-top: 2px solid #bbb;
                    border-bottom: 2px solid #bbb;
                    }
                    tr:hover {
                    background-color: #e6f2ff; /* Light blue */
                    }
                </style>
                <script type="text/javascript">
                    // Initialize table data when the page is loaded
                    var tableData = [];
                    var totalRows = 0;
                    var debounceTimeout = null;
                    
                    // Pre-process the table data for faster filtering
                    function initializeTableData() {
                    var table = document.getElementById("unitTable");
                    var rows = table.getElementsByTagName("tr");
                    totalRows = rows.length - 1; // Subtract header row
                    
                    // Store searchable data for each row
                    for (var i = 1; i &lt; rows.length; i++) {
                    var cells = rows[i].getElementsByTagName("td");
                    var rowData = {
                    element: rows[i],
                    searchText: ""
                    };
                    
                    // Only include columns we want to search (0, 1, 2, 3, 4, 5)
                    var columnsToSearch = [0, 1, 2, 3, 4, 5];
                    for (var j = 0; j &lt; columnsToSearch.length; j++) {
                    var colIndex = columnsToSearch[j];
                    if (colIndex &lt; cells.length) {
                    var cellText = cells[colIndex].textContent || cells[colIndex].innerText;
                    rowData.searchText += cellText.toUpperCase() + " ";
                    }
                    }
                    
                    tableData.push(rowData);
                    }
                    
                    // Update the row count display initially
                    updateRowCount(totalRows);
                    }
                    
                    function updateRowCount(visibleRows) {
                    var countElement = document.getElementById("rowCount");
                    if (countElement) {
                    countElement.textContent = "Showing " + visibleRows + " of " + totalRows + " records";
                    }
                    }
                    
                    function filterTable() {
                    // Get input value
                    var input = document.getElementById("filterInput");
                    var filter = input.value.toUpperCase();
                    var visibleRows = 0;
                    
                    // Use the pre-processed data for faster filtering
                    for (var i = 0; i &lt; tableData.length; i++) {
                    var visible = filter === "" || tableData[i].searchText.indexOf(filter) > -1;
                    tableData[i].element.style.display = visible ? "" : "none";
                    if (visible) {
                    visibleRows++;
                    }
                    }
                    
                    // Update the row count display
                    updateRowCount(visibleRows);
                    }
                    
                    // Debounce function to avoid excessive filtering for fast typers
                    function debounceFilter() {
                    if (debounceTimeout) {
                    clearTimeout(debounceTimeout);
                    }
                    debounceTimeout = setTimeout(function() {
                    filterTable();
                    }, 250); // 250ms delay
                    }
                    
                    // Set up event listeners when the document is loaded
                    document.addEventListener('DOMContentLoaded', function() {
                    // Initialize the table data for faster searching
                    initializeTableData();
                    
                    var input = document.getElementById("filterInput");
                    
                    // Real-time filtering with debouncing
                    input.addEventListener('input', debounceFilter);
                    
                    // Apply filter when Enter key is pressed (immediate, no debounce)
                    input.addEventListener('keypress', function(event) {
                    if (event.key === 'Enter') {
                    if (debounceTimeout) {
                    clearTimeout(debounceTimeout);
                    }
                    filterTable();
                    // Prevent form submission if within a form
                    event.preventDefault();
                    }
                    });
                    });
                </script>
            </head>
            <body>
                <div class="header-container">
                    <div class="logo">
                        <img src="https://diggsml.org/def/img/diggs-logo.png" style="width:150px"/>
                    </div>
                    <div class="title-container">
                        <h1>Unit Dictionary</h1>
                    </div>
                    <!-- Empty div to balance the flex layout -->
                    <div style="flex: 0 0 150px;"></div>
                </div>
                
                <div class="search-row">
                    <input type="text" id="filterInput" placeholder="Filter by name, description, symbol, or dimension..."/>
                    <div id="rowCount"></div>
                </div>
                
                <div class="container">
                    <table id="unitTable">
                        <tr>
                            <th>QuantityClass<br/>Name</th>
                            <th>Description</th>
                            <th>Symbol</th>
                            <th>Name</th>
                            <th>Description</th>
                            <th>Dimension</th>
                            <th>Is SI</th>
                            <th>Category</th>
                            <th>Base Unit</th>
                            <th>Conversion<br/>Reference</th>
                            <th>Conversion<br/>Exact?</th>
                            <th>A</th>
                            <th>B</th>
                            <th>C</th>
                            <th>D</th>
                            <th>Underlying<br/>Definition</th>
                        </tr>
                        
                        <!-- Process each quantityClass in order by name -->
                        <xsl:for-each select="//uom:quantityClassSet/uom:quantityClass | //quantityClassSet/quantityClass">
                            <xsl:sort select="uom:name | name"/>
                            
                            <xsl:variable name="qcName" select="uom:name | name"/>
                            <xsl:variable name="qcDescription" select="uom:description | description"/>
                            <xsl:variable name="qcPosition" select="position()"/>
                            <xsl:variable name="rowClass">
                                <xsl:choose>
                                    <xsl:when test="$qcPosition mod 2 = 1">quantity-class-odd</xsl:when>
                                    <xsl:otherwise>quantity-class-even</xsl:otherwise>
                                </xsl:choose>
                            </xsl:variable>
                            
                            <!-- For each memberUnit in this quantityClass -->
                            <xsl:for-each select="uom:memberUnit | memberUnit">
                                <xsl:variable name="memberUnitValue" select="normalize-space(.)"/>
                                
                                <!-- Find the matching unit in unitSet based on symbol -->
                                <xsl:for-each select="//uom:unitSet/uom:unit[normalize-space(uom:symbol) = $memberUnitValue] | 
                                    //unitSet/unit[normalize-space(symbol) = $memberUnitValue]">
                                    <xsl:if test="position() = 1"> <!-- Only use the first matching unit if there are duplicates -->
                                        <tr class="{$rowClass}">
                                            <!-- Repeat quantityClass info for each row (no rowspan) -->
                                            <td><xsl:value-of select="$qcName"/></td>
                                            <td><xsl:value-of select="$qcDescription"/></td>
                                            
                                            <!-- Display unit info from the matching unit element -->
                                            <td><xsl:value-of select="uom:symbol | symbol"/></td>
                                            <td><xsl:value-of select="uom:name | name"/></td>
                                            <td><xsl:value-of select="uom:description | description"/></td>
                                            <td><xsl:value-of select="uom:dimension | dimension"/></td>
                                            <td><xsl:value-of select="uom:isSI | isSI"/></td>
                                            <td><xsl:value-of select="uom:category | category"/></td>
                                            <td><xsl:value-of select="uom:baseUnit | baseUnit"/></td>
                                            <td><xsl:value-of select="uom:conversionRef | conversionRef"/></td>
                                            <td><xsl:value-of select="uom:isExact | isExact"/></td>
                                            <td><xsl:value-of select="uom:A | A"/></td>
                                            <td><xsl:value-of select="uom:B | B"/></td>
                                            <td><xsl:value-of select="uom:C | C"/></td>
                                            <td><xsl:value-of select="uom:D | D"/></td>
                                            <td><xsl:value-of select="uom:underlyingDef | underlyingDef"/></td>
                                        </tr>
                                    </xsl:if>
                                </xsl:for-each>
                                
                                <!-- If no matching unit was found, create a row with just the quantityClass and memberUnit info -->
                                <xsl:if test="not(//uom:unitSet/uom:unit[normalize-space(uom:symbol) = $memberUnitValue] | 
                                    //unitSet/unit[normalize-space(symbol) = $memberUnitValue])">
                                    <tr class="{$rowClass}">
                                        <!-- Repeat quantityClass info for each row (no rowspan) -->
                                        <td><xsl:value-of select="$qcName"/></td>
                                        <td><xsl:value-of select="$qcDescription"/></td>
                                        
                                        <!-- Show only the memberUnit as the symbol -->
                                        <td><xsl:value-of select="$memberUnitValue"/></td>
                                        <td colspan="13">No matching unit found in unitSet</td>
                                    </tr>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:for-each>
                    </table>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
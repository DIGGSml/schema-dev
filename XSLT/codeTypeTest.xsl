<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="xs" version="2.0">
    <xsl:template match="/">
        <html>
            <head>
                <style>
                    .fixed_header {
                        overflow-y: auto;
                        max-height: 650px;
                    }
                    
                    .fixed_header div {
                        box-shadow: 0 0 12px black;
                    }
                    
                    .fixed_header table {
                        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
                        border-collapse: collapse;
                        width: 100%;
                        background-color: #f2f2f2;
                    }
                    
                    .fixed_header th {
                        position: sticky;
                        top: 0;
                        padding-top: 12px;
                        padding-bottom: 12px;
                        text-align: center;
                        background-color: black;
                        color: #FFFFFF;
                        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
                    }
                    
                    .fixed_header td {
                        padding: 8px;
                        text-align: left;
                        border-bottom: 2px solid gray;
                        font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
                        font-size: 18px;
                        cursor: pointer;
                    }
                    
                    .selected {
                        color: white;
                    }
                    
                    .fixed_header tr:nth-child(even) {
                        background-color: #f2f2f2;
                    }
                    
                    .fixed_header tr:nth-child(odd) {
                        background-color: #DCDCDC;
                    }</style>
            </head>
            <body>
                <table class="fixed_header">
                    <tr>
                        <th>Parent Type</th>
                        <th>Element Type</th>
                        <th>Element Name</th>
                        <th>Description</th>
                    </tr>
                    <xsl:for-each select="//xs:element[@type[contains(., 'Code')]]">
                        <xsl:sort select="xs:element/@name"/>
                        <xsl:sort select="ancestor::xs:complexType/@name"/>
                         <tr>
                        <td><xsl:value-of select="ancestor::xs:complexType/@name"/></td>
                        <td><xsl:value-of select="@type"/></td>
                        <td><xsl:value-of select="@name"/></td>
                        <td><xsl:value-of select="descendant::xs:documentation"/></td>
                        </tr>
                    </xsl:for-each>
                </table>
            </body>
        </html>

    </xsl:template>
</xsl:stylesheet>

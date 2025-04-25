<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
    xmlns="urn:schemas-microsoft-com:office:spreadsheet"
    xmlns:o="urn:schemas-microsoft-com:office:office"
    xmlns:x="urn:schemas-microsoft-com:office:excel"
    xmlns:html="http://www.w3.org/TR/REC-html40"
    xmlns:uom="http://www.energistics.org/energyml/data/uomv1">
    
    <xsl:output method="xml" indent="yes"/>
    
    <!-- Main template -->
    <xsl:template match="/">
        <!-- Create Excel workbook structure -->
        <ss:Workbook>
            <ss:Styles>
                <ss:Style ss:ID="Default" ss:Name="Normal">
                    <ss:Alignment ss:Vertical="Bottom"/>
                    <ss:Font ss:FontName="Calibri" ss:Size="11" ss:Color="#000000"/>
                </ss:Style>
                <ss:Style ss:ID="Header">
                    <ss:Font ss:FontName="Calibri" ss:Size="11" ss:Color="#000000" ss:Bold="1"/>
                </ss:Style>
            </ss:Styles>
            
            <ss:Worksheet ss:Name="Quantity Classes">
                <ss:Table>
                    <!-- Define column width -->
                    <ss:Column ss:Width="300"/>
                    
                    <!-- Create header row -->
                    <ss:Row>
                        <ss:Cell ss:StyleID="Header">
                            <ss:Data ss:Type="String">Quantity Class Names</ss:Data>
                        </ss:Cell>
                    </ss:Row>
                    
                    <!-- Use namespace-aware selection -->
                    <xsl:for-each select="//uom:quantityClass/uom:name | //quantityClass/name">
                        <xsl:sort select="." order="ascending"/>
                        <ss:Row>
                            <ss:Cell>
                                <ss:Data ss:Type="String"><xsl:value-of select="."/></ss:Data>
                            </ss:Cell>
                        </ss:Row>
                    </xsl:for-each>
                </ss:Table>
            </ss:Worksheet>
        </ss:Workbook>
    </xsl:template>
    
</xsl:stylesheet>
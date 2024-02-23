<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions">
    
    <xsl:output method="xml"/>
    
    <xsl:template match="/">
        
        <xsl:copy>
            
            <xsl:apply-templates mode="rootcopy"/>
            
        </xsl:copy>
        
    </xsl:template>
    
    
    
    <xsl:template match="node()" mode="rootcopy">
        
        <xsl:copy>
            
            <xsl:variable name="folderURI" select="resolve-uri('.',base-uri())"/>
            
            <xsl:for-each select="collection(concat($folderURI, '?select=*.xsd;recurse=yes'))/*/node()">
                
                <xsl:apply-templates mode="copy" select="."/>
                
            </xsl:for-each>
            
        </xsl:copy>
        
    </xsl:template>
    
    
    
    <!-- Deep copy template -->
    
    <xsl:template match="node()|@*" mode="copy">
        
        <xsl:copy>
            
            <xsl:apply-templates mode="copy" select="@*"/>
            
            <xsl:apply-templates mode="copy"/>
            
        </xsl:copy>
        
    </xsl:template>
    
    
    
    <!-- Handle default matching -->
    
    <xsl:template match="*"/>
    
</xsl:stylesheet>
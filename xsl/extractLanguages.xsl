<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="2.0">
  
  <xsl:output method="text" encoding="UTF-8"/>
  
  <xsl:template match="/">
    <!-- Extract languages as comma-separated list -->
    <xsl:text>languages=</xsl:text>
    <xsl:for-each select="/site/languages/lang">
      <xsl:value-of select="@code"/>
      <xsl:if test="position() != last()">,</xsl:if>
    </xsl:for-each>
    <xsl:text>&#10;</xsl:text>
    
    <!-- Extract default language -->
    <xsl:text>defaultLang=</xsl:text>
    <xsl:choose>
      <xsl:when test="/site/languages/lang[@default='true']">
        <xsl:value-of select="/site/languages/lang[@default='true'][1]/@code"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="/site/languages/lang[1]/@code"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#10;</xsl:text>
    
    <!-- Count languages -->
    <xsl:text>languageCount=</xsl:text>
    <xsl:value-of select="count(/site/languages/lang)"/>
    <xsl:text>&#10;</xsl:text>
    
    <!-- Check for language selector -->
    <xsl:text>hasLanguageSelector=</xsl:text>
    <xsl:choose>
      <xsl:when test="/site/languageSelector">true</xsl:when>
      <xsl:otherwise>false</xsl:otherwise>
    </xsl:choose>
    <xsl:text>&#10;</xsl:text>
    
    <!-- Extract CSS and JS file paths for cache busting -->
    <xsl:text>cssFile=</xsl:text>
    <xsl:value-of select="/site/files/cssFile"/>
    <xsl:text>&#10;</xsl:text>
    
    <xsl:text>jsFile=</xsl:text>
    <xsl:value-of select="/site/files/jsFile"/>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>
  
</xsl:stylesheet>

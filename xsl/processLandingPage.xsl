<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema" 
                exclude-result-prefixes="#all" 
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                version="3.0">
  
  <xsl:output method="html" 
              indent="yes" 
              encoding="UTF-8" 
              omit-xml-declaration="yes"/>
  
  <!-- Parameters -->
  <xsl:param name="isMultilingual" select="'false'"/>
  <xsl:param name="currentLang" select="''"/>
  <xsl:param name="defaultLang" select="'en'"/>
  <xsl:param name="languages" select="'en'"/>
  
  <!-- Convert string parameters to usable values -->
  <xsl:variable name="isMultilingualBool" select="$isMultilingual = 'true'"/>
  <xsl:variable name="lang" select="if ($currentLang != '') then $currentLang else $defaultLang"/>
  
  <!-- Image dimensions handling -->
  <xsl:variable name="txtDimensions" select="unparsed-text('../utilities/imageDimensions.txt')"/>
  
  <xsl:variable name="mapImgPathsToElements" as="map(xs:string, element(Q{http://www.w3.org/1999/xhtml}img))">
    <xsl:map>
      <xsl:for-each select="distinct-values(tokenize($txtDimensions, '&#x0A;'))">
        <xsl:variable name="bits" as="xs:string*" select="tokenize(., '\s+')"/>
        <xsl:variable name="wh" as="xs:string*" select="if (count($bits) gt 1) then tokenize($bits[2], 'x') else ()"/>
        <xsl:if test="count($bits) = 2 and count($wh) = 2">
          <xsl:map-entry key="$bits[1]">
            <img xmlns="http://www.w3.org/1999/xhtml" src="{$bits[1]}" width="{$wh[1]}" height="{$wh[2]}"/>
          </xsl:map-entry>
        </xsl:if>
      </xsl:for-each>
    </xsl:map>
  </xsl:variable>
  
  <!-- Convert XHTML-namespaced elements to no-namespace HTML5 -->
  <xsl:template match="xhtml:html" priority="3">
    <xsl:element name="html">
      <xsl:copy-of select="@*[not(local-name() = 'id')]"/>
      <xsl:if test="not(@id)">
        <xsl:attribute name="id" select="'index'"/>
      </xsl:if>
      <xsl:apply-templates select="node()"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="xhtml:*" priority="2">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Identity template for attributes -->
  <xsl:template match="@*" priority="1">
    <xsl:copy/>
  </xsl:template>
  
  <!-- Fix resource paths (CSS, JS, images) for multilingual builds -->
  <xsl:template match="xhtml:link/@href[not(starts-with(., 'http')) and not(starts-with(., '/'))]" priority="3">
    <xsl:attribute name="href">
      <xsl:if test="$isMultilingualBool">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="xhtml:script/@src[not(starts-with(., 'http')) and not(starts-with(., '/'))]" priority="3">
    <xsl:attribute name="src">
      <xsl:if test="$isMultilingualBool">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="xhtml:img/@src[not(starts-with(., 'http')) and not(starts-with(., '/'))]" priority="3">
    <xsl:attribute name="src">
      <xsl:if test="$isMultilingualBool">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <!-- Fix internal page links for multilingual builds -->
  <xsl:template match="xhtml:a/@href[not(starts-with(., 'http')) and 
      not(starts-with(., 'https')) and
      not(starts-with(., '#')) and 
      not(starts-with(., '/')) and
      not(contains(., '://')) and
      ends-with(., '.html')]" priority="2">
    <xsl:attribute name="href">
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <!-- Replace img tags with dimensioned versions -->
  <xsl:template match="xhtml:img[starts-with(@src, 'images/') or starts-with(@src, '/images/')]" priority="4">
    <!-- Normalize the src path (remove leading slash if present) -->
    <xsl:variable name="normalizedSrc" select="replace(@src, '^/', '')"/>
    <xsl:variable name="imgTag" select="map:get($mapImgPathsToElements, $normalizedSrc)" as="element(xhtml:img)*"/>
    <xsl:choose>
      <xsl:when test="count($imgTag) > 0">
        <xsl:variable name="currImg" select="."/>
        <xsl:for-each select="$imgTag">
          <xsl:copy>
            <xsl:copy-of select="@width"/>
            <xsl:copy-of select="@height"/>
            <xsl:choose>
              <xsl:when test="$currImg/@class">
                <xsl:attribute name="class" select="concat($currImg/@class, ' ', ./@class)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:copy-of select="@class"/>
              </xsl:otherwise>
            </xsl:choose>
            <!-- Fix src path for multilingual builds -->
            <xsl:attribute name="src">
              <xsl:if test="$isMultilingualBool">../</xsl:if>
              <xsl:value-of select="@src"/>
            </xsl:attribute>
            <xsl:copy-of select="$currImg/@*[not(local-name() = 'width' or local-name() = 'height' or local-name() = 'class' or local-name() = 'src')]"/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>Warning: No dimensions found for <xsl:value-of select="@src"/></xsl:message>
        <xsl:copy>
          <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
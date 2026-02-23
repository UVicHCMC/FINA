<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema" 
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                exclude-result-prefixes="#all" 
                version="3.0">
  
  <xsl:output method="html" indent="yes" encoding="UTF-8" omit-xml-declaration="yes"/>
  
  <!-- Parameters passed from build -->
  <xsl:param name="currentLang" select="'en'"/>
  <xsl:param name="languages" select="'en'"/>
  
  <!-- Get current document filename and page name -->
  <xsl:variable name="currentFile" select="tokenize(base-uri(/), '/')[last()]"/>
  <xsl:variable name="currentPage" select="replace($currentFile, '\.xml$', '.html')"/>
  
  <!-- Load properties to get valid language codes (use static-base-uri to resolve relative to XSLT file) -->
  <xsl:variable name="propertiesDoc" select="document(resolve-uri('../properties.xml', static-base-uri()))"/>
  <xsl:variable name="validLangCodes" select="$propertiesDoc/site/languages/lang/@code"/>
  
  <!-- Determine language from path (for bilingual builds) or use parameter -->
  <xsl:variable name="pathParts" select="tokenize(base-uri(/), '/')"/>
  <xsl:variable name="langFromPath" select="
    if ($pathParts[last() - 1] = $validLangCodes) then
      $pathParts[last() - 1]
    else ''
                  "/>
  
  <!-- Use explicit parameter if provided, otherwise detect from path -->
  <xsl:variable name="lang" select="
    if ($currentLang != '' and $currentLang != 'en') then 
      $currentLang 
    else if ($langFromPath != '') then 
      $langFromPath
    else 
      'en'
  "/>
  
  <!-- Load the appropriate template -->
  <xsl:variable name="templatePath" select="
    if ($langFromPath != '') then
      concat('../templates/', $lang, '/contentPage.xml')
    else
      '../templates/contentPage.xml'
                  "/>
  
  <xsl:variable name="template" select="doc($templatePath)"/>
  
  <!-- Store the content document root for later use -->
  <xsl:variable name="contentRoot" select="/"/>
  
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
  
  <!-- Main template: Process the template document, not the content -->
  <xsl:template match="/">
    <xsl:apply-templates select="$template/*"/>
  </xsl:template>
  
  <!-- Add page id based on output filename -->
  <xsl:template match="xhtml:html" priority="3">
    <xsl:variable name="pageId" select="replace($currentPage, '\.html$', '')"/>
    <xsl:element name="html">
      <xsl:copy-of select="@*[not(local-name() = 'id')]"/>
      <xsl:if test="not(@id)">
        <xsl:attribute name="id" select="$pageId"/>
      </xsl:if>
      <xsl:apply-templates select="node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Convert XHTML-namespaced template elements to HTML5 (no namespace) -->
  <xsl:template match="xhtml:*" priority="2">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Convert XHTML-namespaced content elements to no-namespace HTML in content mode -->
  <xsl:template match="xhtml:*" mode="content" priority="2">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@* | node()" mode="content"/>
    </xsl:element>
  </xsl:template>

  <!-- Handle SVG elements - preserve SVG namespace -->
  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/2000/svg']" priority="3">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/2000/svg">
      <xsl:apply-templates select="@* | node()"/>
    </xsl:element>
  </xsl:template>

  <!-- Handle SVG elements in content mode - preserve SVG namespace -->
  <xsl:template match="*[namespace-uri() = 'http://www.w3.org/2000/svg']" mode="content" priority="3">
    <xsl:element name="{local-name()}" namespace="http://www.w3.org/2000/svg">
      <xsl:apply-templates select="@* | node()" mode="content"/>
    </xsl:element>
  </xsl:template>

  <!-- Identity template for attributes -->
  <xsl:template match="@*" priority="1">
    <xsl:copy/>
  </xsl:template>
  
  <!-- Fix resource paths (CSS, JS, images) for multilingual builds. We do this because the resources are one level up from the HTML pages in bilingual builds. -->
  <xsl:variable name="isMultilingual" select="count(tokenize($languages, ',')) gt 1"/>
  
  <xsl:template match="xhtml:link/@href[not(starts-with(., 'http')) and not(starts-with(., '/')) and (contains(., 'css/') or contains(., 'fonts/'))]" priority="3">
    <xsl:attribute name="href">
      <xsl:if test="$isMultilingual">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="xhtml:script/@src[not(starts-with(., 'http')) and not(starts-with(., '/')) and contains(., 'js/')]" priority="3">
    <xsl:attribute name="src">
      <xsl:if test="$isMultilingual">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="xhtml:img/@src[not(starts-with(., 'http')) and not(starts-with(., '/')) and starts-with(., 'images/')]" priority="4">
    <xsl:attribute name="src">
      <xsl:if test="$isMultilingual">../</xsl:if>
      <xsl:value-of select="."/>
    </xsl:attribute>
  </xsl:template>
  
  <!-- Replace <?docContent?> with actual content -->
  <xsl:template match="processing-instruction('docContent')" priority="5">
    <xsl:message>Inserting content for page: <xsl:value-of select="$currentPage"/></xsl:message>
    <xsl:apply-templates select="$contentRoot/*/*" mode="content"/>
  </xsl:template>
  
  <!-- Replace {{currentPage}} placeholders in href attributes -->
  <xsl:template match="@href[contains(., '{{currentPage}}')]" priority="3">
    <xsl:attribute name="href" select="replace(., '\{\{currentPage\}\}', $currentPage)"/>
  </xsl:template>
  
  <!-- Process content in content mode (identity transform with image handling) -->
  <xsl:template match="xhtml:* | @*" mode="content" priority="1">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="content"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Handle non-namespaced elements from content files -->
  <xsl:template match="*[not(namespace-uri())]" mode="content" priority="1">
    <xsl:element name="{local-name()}">
      <xsl:apply-templates select="@* | node()" mode="content"/>
    </xsl:element>
  </xsl:template>
  
  <!-- Handle text nodes -->
  <xsl:template match="text() | comment() | processing-instruction()" mode="content">
    <xsl:copy/>
  </xsl:template>
  
  <!-- Replace img tags with dimensioned versions (for template images) -->
  <xsl:template match="xhtml:img[starts-with(@src, 'images/') or starts-with(@src, '/images/')]" priority="4">
    <xsl:call-template name="add-image-dimensions">
      <xsl:with-param name="img" select="."/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- Replace img tags with dimensioned versions (for content images) -->
  <xsl:template match="xhtml:img[starts-with(@src, 'images/') or starts-with(@src, '/images/')]" mode="content" priority="4">
    <xsl:call-template name="add-image-dimensions">
      <xsl:with-param name="img" select="."/>
    </xsl:call-template>
  </xsl:template>

  <!-- Named template to add image dimensions -->
  <xsl:template name="add-image-dimensions">
    <xsl:param name="img" as="element(xhtml:img)"/>
    
    <!-- Normalize the src path (remove leading slash if present) -->
    <xsl:variable name="normalizedSrc" select="replace($img/@src, '^/', '')"/>
    <xsl:variable name="imgTag" select="map:get($mapImgPathsToElements, $normalizedSrc)" as="element(xhtml:img)*"/>
    
    <xsl:choose>
      <xsl:when test="count($imgTag) > 0">
        <xsl:for-each select="$imgTag">
          <xsl:copy>
            <xsl:copy-of select="@width"/>
            <xsl:copy-of select="@height"/>
            <xsl:variable name="aspectClass">
              <xsl:choose>
                <xsl:when test="@width eq @height">
                  <xsl:value-of select="'square'"/>
                </xsl:when>
                <xsl:when test="@width &gt; @height">
                  <xsl:value-of select="'landscape'"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="'portrait'"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:choose>
              <xsl:when test="$img/@class">
                <xsl:attribute name="class" select="normalize-space(string-join(($img/@class, $aspectClass), ' '))"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="class" select="$aspectClass"/>
              </xsl:otherwise>
            </xsl:choose>
            <!-- Fix src path for multilingual builds -->
            <xsl:attribute name="src">
              <xsl:if test="$isMultilingual">../</xsl:if>
              <xsl:value-of select="@src"/>
            </xsl:attribute>
            <xsl:copy-of select="$img/@*[not(local-name() = 'width' or local-name() = 'height' or local-name() = 'class' or local-name() = 'src')]"/>
          </xsl:copy>
        </xsl:for-each>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message>Warning: No dimensions found for <xsl:value-of select="$img/@src"/></xsl:message>
        <xsl:copy>
          <xsl:apply-templates select="$img/@* | $img/node()" mode="#current"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
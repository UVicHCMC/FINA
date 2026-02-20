<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema" 
                xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl"
                exclude-result-prefixes="#all" 
                xmlns="http://www.w3.org/1999/xhtml"
                xmlns:xhtml="http://www.w3.org/1999/xhtml"
                xmlns:hcmc="http://hcmc.uvic.ca/ns"
                xmlns:tei="http://www.tei-c.org/ns/1.0"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                version="3.0">
  
  <xsl:output method="xml" indent="yes" encoding="UTF-8" omit-xml-declaration="no"/>
  
  <!-- Load properties file -->
  <xsl:variable name="propertiesDoc" select="document(resolve-uri('../properties.xml', base-uri(/)))"/>
  <xsl:variable name="properties" select="$propertiesDoc/site"/>
  
  <!-- Parameters for language -->
  <xsl:param name="lang" select="'en'"/>
  <xsl:param name="languages" select="'en'"/>
  
  <!-- Check if bilingual -->
  <xsl:variable name="isBilingual" select="contains($languages, ',')"/>

  <!-- Detect if this template is a landing page (no docContent PI) -->
  <xsl:variable name="isLanding" select="not(//processing-instruction('docContent'))"/>
  
  <!-- Get list of all languages -->
  <xsl:variable name="langList" select="tokenize($languages, ',')" />
  
  <!-- Build language labels map from properties.xml -->
  <xsl:variable name="langLabels" as="map(xs:string, xs:string)">
    <xsl:map>
      <xsl:for-each select="$properties/languages/lang">
        <xsl:map-entry key="string(@code)" select="string(@label)"/>
      </xsl:for-each>
    </xsl:map>
  </xsl:variable>
  
  <!-- Get label for other language, fallback to capitalized code -->
  <xsl:function name="hcmc:getLanguageLabel" as="xs:string">
    <xsl:param name="langCode" as="xs:string"/>
    <xsl:sequence select="
      if (map:contains($langLabels, $langCode)) then
        map:get($langLabels, $langCode)
      else
        upper-case(substring($langCode, 1, 1)) || substring($langCode, 2)
                    "/>
  </xsl:function>
  
  <!-- Main template -->
  <xsl:template match="/">
    <xsl:comment>DO NOT EDIT THESE FILES. THEY ARE OVERWRITTEN DURING THE BUILD PROCESS</xsl:comment>
    <xsl:comment>If you want to edit template files, edit those in the boilerplate/ folder</xsl:comment>
    <xsl:apply-templates select="." mode="process-template"/>
  </xsl:template>
  
  <!-- Process template elements -->
  <xsl:template match="xhtml:* | @* | node()" mode="process-template">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="process-template"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Process elements with class="lang-chooser" -->
  <xsl:template match="xhtml:*[contains(@class, 'lang-chooser')]" mode="process-template" priority="3">
    <xsl:variable name="elementName" select="local-name()"/>
    
    <xsl:choose>
      <!-- Two languages: populate single element with other language -->
      <xsl:when test="count($langList) = 2">
        <xsl:variable name="otherLang" select="string($langList[not(. = $lang)][1])"/>
        <xsl:variable name="otherLangLabel" select="upper-case(string($otherLang))"/>
        <!-- Get the aria-label from the other language's label in languages section -->
        <xsl:variable name="ariaLabel" select="$properties/languages/lang[@code = $otherLang]/@label"/>
        
        <xsl:element name="{$elementName}">
          <!-- Process each attribute -->
          <xsl:for-each select="@*">
            <xsl:choose>
              <!-- Empty or computed attributes get filled -->
              <xsl:when test="local-name() = 'aria-label' and string-length(.) = 0">
                <xsl:attribute name="aria-label" select="$ariaLabel"/>
              </xsl:when>
              <xsl:when test="local-name() = 'lang' and string-length(.) = 0">
                <xsl:attribute name="lang" select="$otherLang"/>
              </xsl:when>
              <xsl:when test="local-name() = 'hreflang' and string-length(.) = 0">
                <xsl:attribute name="hreflang" select="$otherLang"/>
              </xsl:when>
              <xsl:when test="local-name() = 'href' and (string-length(.) = 0 or $elementName = 'a')">
                <xsl:attribute name="href">
                  <xsl:text>../</xsl:text>
                  <xsl:value-of select="$otherLang"/>
                  <xsl:text>/</xsl:text>
                  <xsl:choose>
                    <xsl:when test="$isLanding">index.html</xsl:when>
                    <xsl:otherwise>{{currentPage}}</xsl:otherwise>
                  </xsl:choose>
                </xsl:attribute>
              </xsl:when>
              <!-- Skip href-lang or other non-standard attributes with empty values -->
              <xsl:when test="string-length(.) = 0">
                <!-- Don't output empty attributes -->
              </xsl:when>
              <!-- Copy other attributes normally -->
              <xsl:otherwise>
                <xsl:apply-templates select="." mode="process-template"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
          
          <!-- Process content, use computed label if empty -->
          <xsl:choose>
            <xsl:when test="node()">
              <xsl:apply-templates select="node()" mode="process-template"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="$otherLangLabel"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:element>
      </xsl:when>
      
      <!-- Three or more languages: generate dropdown -->
      <xsl:when test="count($langList) gt 2">
        <div id="languageSwitcher" class="language-switcher-dropdown">
          <button class="language-switcher-button">
            <xsl:value-of select="hcmc:getLanguageLabel($lang)"/>
            <span class="dropdown-arrow">▼</span>
          </button>
          <ul class="language-switcher-menu">
            <xsl:for-each select="$langList[not(. = $lang)]">
              <li>
                <a>
                  <xsl:attribute name="href">
                    <xsl:text>../</xsl:text>
                    <xsl:value-of select="."/>
                    <xsl:text>/</xsl:text>
                    <xsl:choose>
                      <xsl:when test="$isLanding">index.html</xsl:when>
                      <xsl:otherwise>{{currentPage}}</xsl:otherwise>
                    </xsl:choose>
                  </xsl:attribute>
                  <xsl:value-of select="hcmc:getLanguageLabel(.)"/>
                </a>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:when>
      
      <!-- Single language: don't output anything (no language chooser/switcher needed) -->
      <xsl:when test="count($langList) = 1">
        <!-- No output for monolingual sites -->
      </xsl:when>
      
    </xsl:choose>
  </xsl:template>
  
  <!-- Process attributes with placeholders -->
  <xsl:template match="@*[contains(., '{?') and contains(., '}')]" mode="process-template" priority="2">
    <xsl:attribute name="{name()}">
      <xsl:call-template name="replace-placeholders">
        <xsl:with-param name="text" select="."/>
      </xsl:call-template>
    </xsl:attribute>
  </xsl:template>
  
  <!-- ============================================================
       GENERIC PROCESSING INSTRUCTION HANDLER
       Automatically looks up any PI name in properties.xml
       ============================================================ -->
  <xsl:template match="processing-instruction()" mode="process-template" priority="1">
    <xsl:variable name="piName" select="name()"/>
    <xsl:variable name="element" select="$properties//*[local-name() = $piName]"/>
    
    <xsl:choose>
      <!-- Special handling for specific PIs that need custom logic -->
      <xsl:when test="$piName = 'other-lang'">
        <xsl:value-of select="$properties/lang-config/*[local-name() = $lang]/other-lang"/>
      </xsl:when>
      
      <xsl:when test="$piName = 'other-lang-text'">
        <xsl:value-of select="$properties/lang-config/*[local-name() = $lang]/other-lang-text"/>
      </xsl:when>
      
      <xsl:when test="$piName = 'lang-abbreviation'">
        <xsl:value-of select="$properties/lang-config/*[local-name() = $lang]/other-lang-text"/>
      </xsl:when>
      
      <xsl:when test="$piName = 'other-lang-href'">
        <xsl:variable name="otherLang" select="$properties/lang-config/*[local-name() = $lang]/other-lang"/>
        <xsl:text>../</xsl:text>
        <xsl:value-of select="$otherLang"/>
        <xsl:text>/</xsl:text>
        <xsl:choose>
          <xsl:when test="$isLanding">index.html</xsl:when>
          <xsl:otherwise>{{currentPage}}</xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      
      <xsl:when test="$piName = 'navigation'">
        <xsl:call-template name="build-navigation"/>
      </xsl:when>
      
      <xsl:when test="$piName = 'docContent'">
        <xsl:processing-instruction name="docContent"/>
      </xsl:when>
      
      <!-- Element found in properties.xml -->
      <xsl:when test="$element">
        <xsl:call-template name="render-property-element">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Not found - output warning and pass through -->
      <xsl:otherwise>
        <xsl:message>Warning: No handler or property found for PI: &lt;?<xsl:value-of select="$piName"/>?&gt;</xsl:message>
        <xsl:copy/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- ============================================================
       GENERIC PROPERTY ELEMENT RENDERER
       Determines what type of content an element has and renders appropriately
       ============================================================ -->
  <xsl:template name="render-property-element">
    <xsl:param name="element"/>
    
    <xsl:choose>
      <!-- Element has @type="img-link" or has both href and src - render as linked image -->
      <xsl:when test="$element/@type = 'img-link' or ($element/href and $element/src)">
        <xsl:call-template name="render-img-link">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Element has @type="img" - render as image -->
      <xsl:when test="$element/@type = 'img' or $element/src">
        <xsl:call-template name="render-img">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Element has @type="link" or has href - render as link -->
      <xsl:when test="$element/@type = 'link' or ($element/href and not($element/src))">
        <xsl:call-template name="render-link">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Element has <items> children - render as list -->
      <xsl:when test="$element/items">
        <xsl:call-template name="render-list">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Element has HTML children (any non-language element children) -->
      <xsl:when test="$element/*[not(local-name() = ('en', 'de', 'fr', 'es', 'it', 'pt', 'nl', 'ru', 'zh', 'ja', 'ko'))]">
        <xsl:call-template name="render-html-content">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:when>
      
      <!-- Simple text content (possibly with language variants) -->
      <xsl:otherwise>
        <xsl:call-template name="get-text-value">
          <xsl:with-param name="element" select="$element"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- ============================================================
       RENDER TEMPLATES FOR DIFFERENT CONTENT TYPES
       ============================================================ -->
  
  <!-- Render an image element -->
  <xsl:template name="render-img">
    <xsl:param name="element"/>
    <xsl:variable name="altText">
      <xsl:call-template name="get-text-value">
        <xsl:with-param name="element" select="$element/alt"/>
      </xsl:call-template>
    </xsl:variable>
    <img src="{$element/src}" alt="{$altText}">
      <xsl:if test="$element/width">
        <xsl:attribute name="width" select="$element/width"/>
      </xsl:if>
      <xsl:if test="$element/height">
        <xsl:attribute name="height" select="$element/height"/>
      </xsl:if>
      <xsl:if test="$element/class">
        <xsl:attribute name="class" select="$element/class"/>
      </xsl:if>
    </img>
  </xsl:template>
  
  <!-- Render a link element -->
  <xsl:template name="render-link">
    <xsl:param name="element"/>
    <xsl:variable name="linkText">
      <xsl:call-template name="get-text-value">
        <xsl:with-param name="element" select="$element/text"/>
      </xsl:call-template>
    </xsl:variable>
    <a href="{$element/href}">
      <xsl:if test="$element/class">
        <xsl:attribute name="class" select="$element/class"/>
      </xsl:if>
      <xsl:if test="$element/aria-label">
        <xsl:attribute name="aria-label">
          <xsl:call-template name="get-text-value">
            <xsl:with-param name="element" select="$element/aria-label"/>
          </xsl:call-template>
        </xsl:attribute>
      </xsl:if>
      <xsl:value-of select="$linkText"/>
    </a>
  </xsl:template>
  
  <!-- Render a linked image element -->
  <xsl:template name="render-img-link">
    <xsl:param name="element"/>
    <xsl:variable name="altText">
      <xsl:call-template name="get-text-value">
        <xsl:with-param name="element" select="$element/alt"/>
      </xsl:call-template>
    </xsl:variable>
    <a href="{$element/href}">
      <xsl:if test="$element/class">
        <xsl:attribute name="class" select="$element/class"/>
      </xsl:if>
      <img src="{$element/src}" alt="{$altText}">
        <xsl:if test="$element/width">
          <xsl:attribute name="width" select="$element/width"/>
        </xsl:if>
        <xsl:if test="$element/height">
          <xsl:attribute name="height" select="$element/height"/>
        </xsl:if>
      </img>
    </a>
  </xsl:template>
  
  <!-- Render a list with items -->
  <xsl:template name="render-list">
    <xsl:param name="element"/>
    <xsl:variable name="wrapperClass" select="$element/@wrapper-class"/>
    <xsl:variable name="listClass" select="$element/@list-class"/>
    
    <xsl:choose>
      <xsl:when test="$wrapperClass">
        <div class="{$wrapperClass}">
          <ul>
            <xsl:if test="$listClass">
              <xsl:attribute name="class" select="$listClass"/>
            </xsl:if>
            <xsl:for-each select="$element/items/item">
              <li>
                <xsl:apply-templates select="node()" mode="render-item-content"/>
              </li>
            </xsl:for-each>
          </ul>
        </div>
      </xsl:when>
      <xsl:otherwise>
        <ul>
          <xsl:if test="$listClass">
            <xsl:attribute name="class" select="$listClass"/>
          </xsl:if>
          <xsl:for-each select="$element/items/item">
            <li>
              <xsl:apply-templates select="node()" mode="render-item-content"/>
            </li>
          </xsl:for-each>
        </ul>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Render item content (handles nested PIs and elements) -->
  <xsl:template match="processing-instruction()" mode="render-item-content">
    <xsl:apply-templates select="." mode="process-template"/>
  </xsl:template>
  
  <xsl:template match="*" mode="render-item-content">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="node()" mode="render-item-content"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="text()" mode="render-item-content">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <!-- Render HTML content (copy structure, resolve language) -->
  <xsl:template name="render-html-content">
    <xsl:param name="element"/>
    <xsl:apply-templates select="$element/*" mode="copy-html-element"/>
  </xsl:template>
  
  <!-- Copy HTML elements, resolving language where needed -->
  <xsl:template match="*" mode="copy-html-element">
    <xsl:element name="{local-name()}">
      <xsl:copy-of select="@*[not(local-name() = map:keys($langLabels))]"/>
      <xsl:choose>
        <xsl:when test="*[local-name() = $lang]">
          <xsl:apply-templates select="*[local-name() = $lang]/node()" mode="copy-html-element"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()" mode="copy-html-element"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="text()" mode="copy-html-element">
    <xsl:value-of select="."/>
  </xsl:template>
  
  <xsl:template match="processing-instruction()" mode="copy-html-element">
    <xsl:apply-templates select="." mode="process-template"/>
  </xsl:template>
  
  <!-- ============================================================
       SPECIAL HANDLERS (navigation, etc.)
       ============================================================ -->
  
  
  <!-- Navigation menu -->
  <xsl:template name="build-navigation">
    <xsl:for-each select="$properties/navigation/item">
      <li>
        <a class="item" href="{@href}">
          <xsl:choose>
            <xsl:when test="*[local-name() = $lang]">
              <xsl:value-of select="*[local-name() = $lang]"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="text()"/>
            </xsl:otherwise>
          </xsl:choose>
        </a>
      </li>
    </xsl:for-each>
  </xsl:template>
  
  <!-- ============================================================
       UTILITY TEMPLATES
       ============================================================ -->
  
  <!-- Template to replace placeholders in attribute values -->
  <xsl:template name="replace-placeholders">
    <xsl:param name="text"/>
    
    <xsl:choose>
      <xsl:when test="contains($text, '{?')">
        <xsl:variable name="before" select="substring-before($text, '{?')"/>
        <xsl:variable name="after" select="substring-after($text, '{?')"/>
        
        <xsl:choose>
          <xsl:when test="contains($after, '}')">
            <xsl:variable name="placeholder" select="substring-before($after, '}')"/>
            <xsl:variable name="remainder" select="substring-after($after, '}')"/>
            
            <!-- Handle special placeholders that need computation -->
            <xsl:variable name="value">
              <xsl:choose>
                <!-- Check lang-config first for language-specific properties -->
                <xsl:when test="$properties/lang-config/*[local-name() = $lang]/*[local-name() = $placeholder]">
                  <xsl:call-template name="get-text-value">
                    <xsl:with-param name="element" select="$properties/lang-config/*[local-name() = $lang]/*[local-name() = $placeholder]"/>
                  </xsl:call-template>
                </xsl:when>
                <!-- Special computed placeholders -->
                <xsl:when test="$placeholder = 'lang-abbreviation'">
                  <xsl:value-of select="$properties/lang-config/*[local-name() = $lang]/other-lang-label"/>
                </xsl:when>
                <xsl:when test="$placeholder = 'other-lang-href'">
                  <xsl:variable name="otherLang" select="$properties/lang-config/*[local-name() = $lang]/other-lang"/>
                  <xsl:text>../</xsl:text>
                  <xsl:value-of select="$otherLang"/>
                  <xsl:text>/</xsl:text>
                  <xsl:choose>
                    <xsl:when test="$isLanding">index.html</xsl:when>
                    <xsl:otherwise>{{currentPage}}</xsl:otherwise>
                  </xsl:choose>
                </xsl:when>
                <!-- Check general properties -->
                <xsl:when test="$properties//*[local-name() = $placeholder]">
                  <xsl:call-template name="get-text-value">
                    <xsl:with-param name="element" select="$properties//*[local-name() = $placeholder]"/>
                  </xsl:call-template>
                </xsl:when>
              </xsl:choose>
            </xsl:variable>
            
            <xsl:choose>
              <xsl:when test="string-length($value) gt 0">
                <!-- Output: before + value + recursively process remainder -->
                <xsl:value-of select="$before"/>
                <xsl:value-of select="$value"/>
                <xsl:call-template name="replace-placeholders">
                  <xsl:with-param name="text" select="$remainder"/>
                </xsl:call-template>
              </xsl:when>
              <xsl:otherwise>
                <xsl:message>Warning: No value found for placeholder {?<xsl:value-of select="$placeholder"/>}</xsl:message>
                <!-- Output: before + recursively process remainder (skip placeholder) -->
                <xsl:value-of select="$before"/>
                <xsl:call-template name="replace-placeholders">
                  <xsl:with-param name="text" select="$remainder"/>
                </xsl:call-template>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:otherwise>
            <!-- Malformed placeholder - just output as-is -->
            <xsl:value-of select="$text"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Template to get text value based on language -->
  <xsl:template name="get-text-value">
    <xsl:param name="element"/>
    
    <xsl:choose>
      <!-- Check for child element matching current language -->
      <xsl:when test="$element/*[local-name() = $lang]">
        <xsl:value-of select="$element/*[local-name() = $lang]"/>
      </xsl:when>
      <!-- Check for attribute matching current language -->
      <xsl:when test="$element/@*[local-name() = $lang]">
        <xsl:value-of select="$element/@*[local-name() = $lang]"/>
      </xsl:when>
      <!-- Fallback to text content (for monolingual) -->
      <xsl:otherwise>
        <xsl:value-of select="normalize-space(string($element))"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
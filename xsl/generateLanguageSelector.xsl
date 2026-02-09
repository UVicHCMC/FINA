<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema" 
                exclude-result-prefixes="#all" 
                version="3.0">
  
  <xsl:output method="html" 
              indent="yes" 
              encoding="UTF-8" 
              omit-xml-declaration="yes"/>
  
  <!-- Parameters -->
  <xsl:param name="languages" select="'en'"/>
  
  <xsl:variable name="langList" select="tokenize($languages, ',')"/>
  
  <xsl:template match="/site">
    <html>
      <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>
          <xsl:choose>
            <xsl:when test="languageSelector/heading/*[local-name() = $langList[1]]">
              <xsl:value-of select="languageSelector/heading/*[local-name() = $langList[1]]"/>
            </xsl:when>
            <xsl:otherwise>Select Language</xsl:otherwise>
          </xsl:choose>
        </title>
        <link rel="stylesheet" href="css/brecht.css"/>
      </head>
      <body class="language-selector">
        <div class="language-selector-container">
          <h1>
            <xsl:choose>
              <xsl:when test="languageSelector/heading/*[local-name() = $langList[1]]">
                <xsl:value-of select="languageSelector/heading/*[local-name() = $langList[1]]"/>
              </xsl:when>
              <xsl:otherwise>Select your language</xsl:otherwise>
            </xsl:choose>
          </h1>
          <select class="language-list" name="language-list">
            <xsl:for-each select="languages/lang">
              <xsl:variable name="langCode" select="@code"/>
              <xsl:variable name="langLabel" select="@label"/>
              <option value="{$langCode}">
                <xsl:value-of select="$langLabel"/>
              </option>
            </xsl:for-each>
          </select>
        </div>
      </body>
    </html>
  </xsl:template>
  
</xsl:stylesheet>

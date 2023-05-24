<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- recalculate each TextRegion text content by concatenating from its TextLine entries
       (but only if the TextRegion does contain TextLines)
       ignore non-first TextEquivs, intersperse with newline characters
  -->
  <xsl:template match="//pc:TextRegion[pc:TextLine]/pc:TextEquiv[1]/pc:Unicode/text()" name="concatenate">
    <xsl:param name="context" select="../../.."/>
    <xsl:for-each select="$context/pc:TextLine">
      <xsl:copy-of select="pc:TextEquiv[1]/pc:Unicode/text()"/>
      <xsl:if test="not(position()=last())">
        <xsl:text>&#10;</xsl:text>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  <!-- if a TextRegion does not have a TextEquiv yet
       create it, and call the concatenation by name
  -->
  <xsl:template match="//pc:TextRegion[pc:TextLine and not(pc:TextEquiv)]">
    <xsl:copy>
      <!-- keep correct order (attributes, elements before TextEquiv, elements after TextEquiv -->
      <xsl:apply-templates select="@*|node()[local-name()!='TextStyle']"/>
      <xsl:if test="not(pc:TextEquiv)">
        <xsl:element name="pc:TextEquiv">
          <xsl:element name="pc:Unicode">
            <xsl:call-template name="concatenate">
              <xsl:with-param name="context" select="."/>
            </xsl:call-template>
          </xsl:element>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="pc:TextStyle"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

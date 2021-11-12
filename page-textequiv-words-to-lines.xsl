<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- recalculate each TextLine text content by concatenating from its Word entries
       (but only if the TextLine does contain Words)
       ignore non-first TextEquivs, intersperse with space characters -->
  <xsl:template match="//pc:TextLine[pc:Word]/pc:TextEquiv[1]/pc:Unicode/text()">
    <xsl:for-each select="../../../pc:Word">
      <xsl:copy-of select="pc:TextEquiv[1]/pc:Unicode/text()"/>
      <xsl:if test="not(position()=last())">
        <xsl:text> </xsl:text>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:strip-space elements="*"/>
  <xsl:preserve-space elements="pc:Unicode"/>
  <xsl:template match="//pc:TextEquiv">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:if test="not(@index)">
        <xsl:attribute name="index">
          <xsl:value-of select="count(preceding-sibling::pc:TextEquiv)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

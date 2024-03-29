<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:template match="//pc:TextEquiv">
    <xsl:variable select="pc:Unicode" name="text"/>
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <!-- despite being allowed by the schema, the PRImA parser crashes when there is no Unicode|Plaintext here -->
      <xsl:if test="not($text)">
        <xsl:element name="pc:Unicode"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

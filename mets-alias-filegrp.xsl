<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mets="http://www.loc.gov/METS/" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:preserve-space elements="*"/>
  <!-- makes a copy of the fileGrp "$input", naming it as "$output" (but without @ID) -->
  <xsl:param name="input" select="'FULLTEXT'"/>
  <xsl:param name="output" select="'ALTO'"/>
  <xsl:template match="/mets:mets/mets:fileSec/mets:fileGrp">
    <xsl:call-template name="identity"/>
    <xsl:if test="@USE=$input">
      <xsl:text>&#xa;    </xsl:text>
      <xsl:copy>
        <xsl:attribute name="USE"><xsl:value-of select="$output"/></xsl:attribute>
        <xsl:apply-templates select="node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

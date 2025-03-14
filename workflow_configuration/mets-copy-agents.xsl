<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:mets="http://www.loc.gov/METS/" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:preserve-space elements="*"/>
  <!-- opens an external METS file $other-mets and copies its metsHdr/agent nodes -->
  <xsl:param name="other-mets" select="'mets.xml'"/>
  <xsl:variable name="other-doc" select="document($other-mets, /)"/>
  <xsl:template match="/mets:mets/mets:metsHdr">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <xsl:for-each select="$other-doc/mets:mets/mets:metsHdr/mets:agent">
        <xsl:copy-of select="."/>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

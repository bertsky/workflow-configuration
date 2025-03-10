<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- catch all RO types (RegionRef|OrderedGroup|UnorderedGroup(Indexed)) -->
  <xsl:template match="//pc:ReadingOrder/*">
    <xsl:variable select="@regionRef" name="regionref"/>
    <xsl:choose>
      <!-- keep groups without regionRefs unconditionally -->
      <xsl:when test="not($regionref)">
        <xsl:call-template name="identity"/>
      </xsl:when>
      <!-- all region types are recursive; for brevity, we use * instead of enumerating all types -->
      <xsl:when test="count(//*[@id=$regionref])>0">
        <xsl:call-template name="identity"/>
      </xsl:when>
      <!-- otherwise skip the RO element (despite being allowed by the schema, the PRImA parser crashes when the regionRef does not exist) -->
    </xsl:choose>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

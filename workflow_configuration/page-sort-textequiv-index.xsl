<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:strip-space elements="*"/>
  <xsl:preserve-space elements="pc:Unicode"/>
  <xsl:template match="//*[pc:TextEquiv]">
    <!-- any hierarchy element that carries text -->
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="pc:AlternativeImage|pc:Coords|pc:Baseline|pc:TextLine|pc:Word|pc:Glyph|pc:Graphemes"/>
      <!--<xsl:apply-templates select="node()[count(following::pc:TextEquiv) &gt; 0 and not(self::pc:TextEquiv)]"/>-->
      <xsl:apply-templates select="pc:TextEquiv">
        <xsl:sort select="@index"/>
      </xsl:apply-templates>
      <xsl:apply-templates select="pc:TextStyle|pc:UserDefined|pc:Labels"/>
      <!--<xsl:apply-templates select="node()[count(preceding::pc:TextEquiv) &gt; 0 and not(self::pc:TextEquiv)]"/>-->
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

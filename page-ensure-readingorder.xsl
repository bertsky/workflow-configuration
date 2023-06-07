<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- if a TextLine does not have a TextEquiv yet
       create it, and call the concatenation by name
  -->
  <xsl:param name="alltypes" select="pc:TextRegion|pc:ImageRegion|pc:LineDrawingRegion|pc:GraphicRegion|pc:TableRegion|pc:ChartRegion|pc:MapRegion|pc:SeparatorRegion|pc:MathsRegion|pc:ChemRegion|pc:MusicRegion|pc:AdvertRegion|pc:NoiseRegion|pc:UnknownRegion|pc:CustomRegion"/>
  <xsl:template name="getgroups">
    <xsl:param name="regions"/>
    <xsl:for-each select="$regions">
      <xsl:choose>
        <xsl:when test="count(pc:TextRegion|pc:ImageRegion|pc:LineDrawingRegion|pc:GraphicRegion|pc:TableRegion|pc:ChartRegion|pc:MapRegion|pc:SeparatorRegion|pc:MathsRegion|pc:ChemRegion|pc:MusicRegion|pc:AdvertRegion|pc:NoiseRegion|pc:UnknownRegion|pc:CustomRegion)>0">
          <!-- recursive case: add regionref and descend into children -->
          <xsl:element name="pc:OrderedGroupIndexed">
            <xsl:attribute name="id">
              <xsl:value-of select="concat('og_',generate-id())"/>
            </xsl:attribute>
            <xsl:attribute name="regionRef">
              <xsl:value-of select="@id"/>
            </xsl:attribute>
            <xsl:attribute name="index">
              <xsl:value-of select="count(preceding-sibling::*)"/>
            </xsl:attribute>
            <xsl:call-template name="getgroups">
              <xsl:with-param name="regions" select="pc:TextRegion|pc:ImageRegion|pc:LineDrawingRegion|pc:GraphicRegion|pc:TableRegion|pc:ChartRegion|pc:MapRegion|pc:SeparatorRegion|pc:MathsRegion|pc:ChemRegion|pc:MusicRegion|pc:AdvertRegion|pc:NoiseRegion|pc:UnknownRegion|pc:CustomRegion"/>
            </xsl:call-template>
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>
          <xsl:element name="pc:RegionRefIndexed">
            <xsl:attribute name="regionRef">
              <xsl:value-of select="@id"/>
            </xsl:attribute>
            <xsl:attribute name="index">
              <xsl:value-of select="count(preceding-sibling::*)"/>
            </xsl:attribute>
          </xsl:element>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="/pc:PcGts/pc:Page">
    <xsl:copy>
      <!-- keep correct order (attributes, elements before ReadingOrder, elements after ReadingOrder -->
      <xsl:apply-templates select="@*|node()[local-name()='AlternativeImage' or local-name()='Border' or local-name()='PrintSpace']"/>
      <xsl:if test="not(pc:ReadingOrder)">
        <xsl:element name="pc:ReadingOrder">
          <xsl:element name="pc:OrderedGroup">
            <xsl:attribute name="id">
              <xsl:value-of select="concat('ro_',generate-id())"/>
            </xsl:attribute>
            <xsl:attribute name="caption">auto-generated from document order</xsl:attribute>
            <xsl:call-template name="getgroups">
              <xsl:with-param name="regions" select="pc:TextRegion|pc:ImageRegion|pc:LineDrawingRegion|pc:GraphicRegion|pc:TableRegion|pc:ChartRegion|pc:MapRegion|pc:SeparatorRegion|pc:MathsRegion|pc:ChemRegion|pc:MusicRegion|pc:AdvertRegion|pc:NoiseRegion|pc:UnknownRegion|pc:CustomRegion"/>
            </xsl:call-template>
          </xsl:element>
        </xsl:element>
      </xsl:if>
      <xsl:apply-templates select="node()[local-name()!='AlternativeImage' and local-name()!='Border' and local-name()!='PrintSpace' and local-name()!='ReadingOrder']"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

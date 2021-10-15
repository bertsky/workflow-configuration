<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:template match="/pc:PcGts/pc:Page/pc:ReadingOrder[count(./pc:OrderedGroup|./pc:UnorderedGroup)=0]"/>
  <xsl:template match="/pc:PcGts/pc:Page/pc:ReadingOrder/pc:OrderedGroup[count(./pc:OrderedGroupIndexed|./pc:UnorderedGroupIndexed|./pc:RegionRefIndexed)=0]"/>
  <xsl:template match="/pc:PcGts/pc:Page/pc:ReadingOrder/pc:UnorderedGroup[count(./pc:OrderedGroup|./pc:UnorderedGroup|./pc:RegionRef)=0]"/>  
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:strip-space elements="*"/>
  <!-- older LAREX versions moved AlternativeImages from all (sub)segments to the page level, which is incorrect
       this tries to move them back by guessing the segment id from the image filename -->

<!-- suppress AlternativeImage on page level for sub-segments
     TODO: needs more elaborate filter than just fixed region/line strings
-->
<xsl:template match="/pc:PcGts/pc:Page/pc:AlternativeImage[
                     contains(@filename,'region') or
                     contains(@filename,'line')]"/>
<!-- copy AlternativeImage by matching filename
     TODO: needs more elaborate regex if identifiers are not directly contained in filenames or may clash
-->
<xsl:template match="*|@*">
  <xsl:copy>
    <xsl:apply-templates select="@*"/>
    <xsl:if test="@id">
      <xsl:variable name="identifier" select="@id"/>
      <xsl:for-each select="/pc:PcGts/pc:Page/pc:AlternativeImage">
        <xsl:if test="contains(@filename,$identifier)">
          <xsl:copy-of select="."/>
        </xsl:if>
      </xsl:for-each>
    </xsl:if>
    <xsl:apply-templates select="node()|text()"/>
  </xsl:copy>
 </xsl:template>
</xsl:stylesheet>

<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>
  <!-- drop-capital vs paragraph sometimes is represented via recursive TextRegions,
       so this converts top-level TextRegion/TextRegion children to siblings
       (removing the shared parent) -->
  <xsl:template match="//pc:Page/pc:TextRegion">
    <xsl:choose>
      <xsl:when test="pc:TextRegion">
        <!-- recursive case -->
        <xsl:if test="pc:TextLine">
          <xsl:message terminate="yes">
            <xsl:text>found recursive TextRegion with TextLines at top: </xsl:text>
            <xsl:value-of select="@id"/>
          </xsl:message>
        </xsl:if>
        <xsl:apply-templates select="pc:TextRegion"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*"/>
          <xsl:apply-templates select="*"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="@* | node() | text()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node() | text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>


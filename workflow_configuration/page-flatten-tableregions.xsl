<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>
  <!-- LAREX cannot present/edit recursive regions, but TableRegion necessitates TextRegion for content
       so this converts TableRegion/TextRegion children to siblings -->
  <xsl:template match="pc:TableRegion">
    <xsl:copy>
        <xsl:apply-templates select="@*"/>
        <xsl:apply-templates select="*[not(local-name()='TextRegion')]"/>
    </xsl:copy>
    <xsl:apply-templates select="pc:TextRegion">
      <xsl:with-param name="custom"><xsl:value-of select="concat('parent:',@id)"/></xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  <xsl:template match="@* | node() | text()">
    <xsl:param name="custom"/>
    <xsl:copy>
      <xsl:if test="$custom">
        <xsl:attribute name="custom">
          <xsl:value-of select="string($custom)"/>
        </xsl:attribute>
      </xsl:if>
      <xsl:apply-templates select="@* | node() | text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>


<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>
  <!-- LAREX cannot present/edit recursive regions,
       so this converts *Region/TextRegion children to siblings -->
  <xsl:param name="type" select="'all'"/>
  <xsl:template match="pc:*[contains(local-name(), 'Region') and substring-after(local-name(), 'Region')='']">
    <xsl:param name="custom"/>
    <xsl:variable name="matched" select="$type='all' or local-name()=$type"/>
    <xsl:copy>
	<xsl:if test="$custom">
          <xsl:attribute name="custom">
            <xsl:value-of select="concat(@custom, ' ', string($custom))"/>
          </xsl:attribute>
	</xsl:if>
        <xsl:apply-templates select="@*[not($custom) or not(local-name()='custom')]"/>
        <xsl:apply-templates select="*[not(local-name()='TextRegion' and $matched)]"/>
    </xsl:copy>
    <xsl:if test="$matched">
      <xsl:apply-templates select="pc:TextRegion">
	<xsl:with-param name="custom"><xsl:value-of select="concat('parent:',@id)"/></xsl:with-param>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>
  <xsl:template match="node()|text()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|text()|@*"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>


<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>
  <!-- LAREX cannot present/edit recursive regions,
       so this moves TextRegion elements previously moved from *Region back as children -->
  <xsl:template match="pc:*[contains(local-name(), 'Region') and substring-after(local-name(), 'Region')='']">
    <xsl:variable name="topid" select="@id"/>
    <xsl:copy>
      <xsl:apply-templates select="@* | node() | text()"/>
      <xsl:for-each select="../pc:TextRegion[contains(@custom,concat('parent:',$topid))]">
	<xsl:variable name="custom" select="substring-before(@custom, ' parent:')"/>
        <xsl:copy>
	  <xsl:if test="$custom">
            <xsl:attribute name="custom">
              <xsl:value-of select="string($custom)"/>
            </xsl:attribute>
	  </xsl:if>
          <xsl:apply-templates select="@*[not(local-name()='custom')]"/>
          <xsl:apply-templates select="node() | text()"/>
        </xsl:copy>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="pc:TextRegion[contains(@custom,'parent:')]"/>
  <xsl:template match="@* | node() | text()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node() | text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>


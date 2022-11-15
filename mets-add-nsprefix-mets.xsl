<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:mets="http://www.loc.gov/METS/">
<xsl:output method="xml" version="1.0" omit-xml-declaration="yes" encoding="UTF-8" indent="yes"/>

<xsl:template match="*">
  <xsl:choose>
    <xsl:when test="not(starts-with(namespace-uri(),'http://www.loc.gov/METS/'))">
      <xsl:copy>
        <xsl:apply-templates select="node()|@*|text()"/>
      </xsl:copy>
    </xsl:when>
    <xsl:otherwise>
      <xsl:element name="mets:{local-name()}">
        <xsl:apply-templates select="@*|node()|text()"/>
      </xsl:element>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<xsl:template match="@*|text()">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*|text()"/>
  </xsl:copy>
 </xsl:template>
</xsl:stylesheet>

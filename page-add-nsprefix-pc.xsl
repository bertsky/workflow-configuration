<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
<xsl:output method="xml" version="1.0" omit-xml-declaration="yes" encoding="UTF-8" indent="yes"/>

<xsl:template match="*">
  <xsl:if test="not(starts-with(namespace-uri(),'http://schema.primaresearch.org/PAGE/gts/pagecontent/'))">
    <xsl:message terminate="yes">
      <xsl:text>input document is not of type http://schema.primaresearch.org/PAGE/gts/pagecontent, but </xsl:text>
      <xsl:value-of select="namespace-uri()"/>
    </xsl:message>
  </xsl:if>
  <xsl:element name="pc:{local-name()}">
    <xsl:apply-templates select="@*|node()|text()"/>
  </xsl:element>
</xsl:template>
<xsl:template match="@*|text()">
  <xsl:copy>
    <xsl:apply-templates select="node()|@*|text()"/>
  </xsl:copy>
 </xsl:template>
</xsl:stylesheet>

<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output
      method="xml"
      standalone="yes"
      encoding="UTF-8"
      omit-xml-declaration="no"/>
  <xsl:template match="//pc:TextRegion"/>
  <xsl:template match="node()|text()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|text()|@*"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

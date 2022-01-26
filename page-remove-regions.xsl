<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output
      method="xml"
      standalone="yes"
      encoding="UTF-8"
      omit-xml-declaration="no"/>
  <xsl:param name="type"/>
  <xsl:template match="node()|text()|@*">
    <xsl:choose>
      <xsl:when test="local-name(.)=$type"/>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="node()|text()|@*"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>

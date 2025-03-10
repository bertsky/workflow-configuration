<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2017-07-15">
  <xsl:output
      method="xml"
      standalone="yes"
      encoding="UTF-8"
      omit-xml-declaration="no"/>
  <xsl:param name="index" select="'all'"/>
  <xsl:template match="node()|text()|@*">
    <xsl:if test="not(local-name()='TextEquiv') or not(($index!='all' and ./@index=$index) or ($index='all'))">
      <xsl:copy>
        <xsl:apply-templates select="node()|text()|@*"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>

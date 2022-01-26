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
  <xsl:template match="//pc:ImageRegion"/>
  <xsl:template match="//pc:LineDrawingRegion"/>
  <xsl:template match="//pc:GraphicRegion"/>
  <xsl:template match="//pc:TableRegion"/>
  <xsl:template match="//pc:ChartRegion"/>
  <xsl:template match="//pc:MapRegion"/>
  <xsl:template match="//pc:SeparatorRegion"/>
  <xsl:template match="//pc:MathsRegion"/>
  <xsl:template match="//pc:ChemRegion"/>
  <xsl:template match="//pc:MusicRegion"/>
  <xsl:template match="//pc:AdvertRegion"/>
  <xsl:template match="//pc:NoiseRegion"/>
  <xsl:template match="//pc:UnknownRegion"/>
  <xsl:template match="//pc:CustomRegion"/>
  <xsl:template match="node()|text()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|text()|@*"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

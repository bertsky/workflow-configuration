<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <!-- rid of xml syntax: -->  
  <xsl:output
      method="text"
      standalone="yes"
      omit-xml-declaration="yes"/>
  <!-- copy text element verbatim: -->  
  <xsl:template match="pc:PcGts/pc:Page/pc:TextRegion/pc:TextLine/pc:Word/pc:TextEquiv[1]">
    <xsl:value-of select="*[text()]" disable-output-escaping="yes"/>
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="pc:PcGts/pc:Page/pc:TextRegion/pc:TextLine/pc:Word[position()>1]">
    <xsl:text> </xsl:text>
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="pc:PcGts/pc:Page/pc:TextRegion/pc:TextLine[position()>1]">
    <xsl:text>
</xsl:text>
    <xsl:apply-templates/>
  </xsl:template>
  <xsl:template match="pc:PcGts/pc:Page/pc:TextRegion[position()>1]">
    <xsl:text>
</xsl:text>
    <xsl:apply-templates/>
  </xsl:template>
  <!-- override implicit rules copying elements and attributes: -->
  <xsl:template match="text()"/>
</xsl:stylesheet>

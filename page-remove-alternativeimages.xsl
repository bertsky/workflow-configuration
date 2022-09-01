<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output
      method="xml"
      standalone="yes"
      indent="yes"
      encoding="UTF-8"
      omit-xml-declaration="no"/>
  <!-- select the hierarchy level to remove from: all|page|region|line|word|glyph -->
  <xsl:param name="level" select="'page'"/>
  <!-- select the image version to remove: all|last|first or any matching @comment string -->
  <xsl:param name="which" select="'last'"/>
  <xsl:template match="//pc:AlternativeImage">
    <xsl:variable name="alllevels" select="$level='all'"/>
    <xsl:variable name="pagelevel" select="$level='page' and local-name(..)='Page'"/>
    <xsl:variable name="regionlevel" select="$level='region' and contains(local-name(..),'Region')"/>
    <xsl:variable name="linelevel" select="$level='line' and local-name(..)='TextLine'"/>
    <xsl:variable name="wordlevel" select="$level='word' and local-name(..)='Word'"/>
    <xsl:variable name="glyphlevel" select="$level='glyph' and local-name(..)='Glyph'"/>
    <xsl:variable name="levelMatches" select="$alllevels or $pagelevel or $regionlevel or $linelevel or $wordlevel or $glyphlevel"/>
    <xsl:variable name="allwitches" select="$which='all'"/>
    <!-- cannot use position()/first()/last() here, as it applies to result tree, not node tree -->
    <xsl:variable name="firstwitch" select="$which='first' and count(preceding-sibling::pc:AlternativeImage)=0"/>
    <xsl:variable name="lastwitch" select="$which='last' and count(following-sibling::pc:AlternativeImage)=0"/>
    <xsl:variable name="featuredwitch" select="contains(@comments,$which)"/>
    <xsl:variable name="whichMatches" select="$allwitches or $firstwitch or $lastwitch or $featuredwitch"/>
    <xsl:choose>
      <xsl:when test="$levelMatches and $whichMatches"/>
      <xsl:otherwise>
        <xsl:copy-of select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="node()|text()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|text()|@*"/>
    </xsl:copy>
  </xsl:template>
  <xsl:strip-space elements="*"/>
</xsl:stylesheet>

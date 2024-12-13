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
  <xsl:template match="//pc:TextRegion[not(./pc:TextLine)]">
    <xsl:choose>
      <xsl:when test="(not($type) or @type=$type)"/>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="node()|text()|@*"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <!-- catch all RO types (RegionRef|OrderedGroup|UnorderedGroup(Indexed)) -->
  <xsl:template match="//pc:ReadingOrder//*">
    <xsl:variable select="@regionRef" name="regionref"/>
    <xsl:choose>
      <!-- keep groups without regionRefs unconditionally -->
      <xsl:when test="not($regionref)">
        <xsl:call-template name="identity"/>
      </xsl:when>
      <!-- all region types are recursive; for brevity, we use * instead of enumerating all types -->
      <xsl:when test="//*[@id=$regionref and not(local-name(.)='TextRegion' and (not($type) or @type=$type) and not(./pc:TextLine))]">
        <xsl:call-template name="identity"/>
      </xsl:when>
      <!-- otherwise skip the RO element (despite being allowed by the schema, the PRImA parser crashes when the regionRef does not exist) -->
    </xsl:choose>
  </xsl:template>
  <xsl:template match="node()|text()|@*" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="node()|text()|@*"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

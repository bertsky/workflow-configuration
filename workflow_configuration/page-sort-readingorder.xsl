<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- use key mechanism for IDREFs, because XSD does not support id mechanism -->
  <xsl:key name="textRegion" match="pc:TextRegion" use="@id"/>
  <xsl:template match="pc:PcGts/pc:Page">
    <xsl:variable name="regions" select="//pc:TextRegion"/>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <!-- elements prior to regions -->
      <xsl:apply-templates select="pc:AlternativeImage|pc:Border|pc:PrintSpace|pc:ReadingOrder|pc:Layers|pc:Relations|pc:TextStyle|pc:UserDefined|pc:Labels|text()"/>
      <!-- text region elements in RO -->
      <xsl:choose>
        <xsl:when test="pc:ReadingOrder//*[@regionRef|@regionRefIndexed]">
          <xsl:call-template name="getrefs">
            <xsl:with-param name="group" select="pc:ReadingOrder/*"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="$regions">
            <xsl:copy>
              <xsl:apply-templates select="@*|node()"/>
            </xsl:copy>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
      <!-- other regions -->
      <xsl:apply-templates select="*[contains(local-name(.), 'Region')]|text()"/>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="//pc:TextRegion"/>
  <xsl:template name="getrefs">
    <xsl:param name="group"/>
    <xsl:for-each select="$group/*">
      <xsl:sort select="@index" data-type="number"/>
      <!--<xsl:variable name="region" select="id(@regionRef|@regionRefIndexed)"/>-->
      <xsl:variable name="region" select="key('textRegion', @regionRef|@regionRefIndexed)"/>
      <xsl:if test="$region">
        <xsl:copy-of select="$region"/>
      </xsl:if>
      <!-- UnorderedGroup(Indexed) and OrderedGroup(Indexed): recurse -->
      <xsl:if test="contains(local-name(.), 'Group')">
        <xsl:call-template name="getrefs">
          <xsl:with-param name="group" select="."/>
        </xsl:call-template>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

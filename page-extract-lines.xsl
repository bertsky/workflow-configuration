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
  <xsl:variable name="newline"><xsl:text>
</xsl:text>
  </xsl:variable>
  <!-- paragraph break -->
  <xsl:param name="pb" select="concat($newline,$newline)"/>
  <!-- line break -->
  <xsl:param name="lb" select="$newline"/>
  <!-- text order: by element or by explicit ReadingOrder -->
  <xsl:param name="order" select="'reading-order'"/>
  <!-- use key mechanism for IDREFs, because XSD does not support id mechanism -->
  <xsl:key name="textRegion" match="pc:TextRegion" use="@id"/>
  <xsl:template match="pc:PcGts/pc:Page">
    <xsl:variable name="regions" select="//pc:TextRegion"/>
    <xsl:choose>
      <xsl:when test="starts-with($order, 'reading-order') and pc:ReadingOrder//*[@regionRef|@regionRefIndexed]">
        <xsl:call-template name="getrefs">
          <xsl:with-param name="group" select="pc:ReadingOrder/*"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$regions">
          <xsl:call-template name="getlines">
            <xsl:with-param name="region" select="."/>
          </xsl:call-template>
          <xsl:value-of select="$pb"/>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="getlines">
    <xsl:param name="region"/>
    <xsl:for-each select="$region/pc:TextLine">
      <xsl:if test="position()>1">
        <xsl:value-of select="$lb"/>
      </xsl:if>
      <xsl:value-of select="pc:TextEquiv[1]/*[text()]" disable-output-escaping="yes"/>
    </xsl:for-each>
  </xsl:template>
  <xsl:template name="getrefs">
    <xsl:param name="group"/>
    <xsl:for-each select="$group/*">
      <xsl:sort select="@index" data-type="number"/>
      <!--<xsl:variable name="region" select="id(@regionRef|@regionRefIndexed)"/>-->
      <xsl:variable name="region" select="key('textRegion', @regionRef|@regionRefIndexed)"/>
      <xsl:if test="$region">
        <xsl:call-template name="getlines">
          <xsl:with-param name="region" select="$region"/>
        </xsl:call-template>
        <xsl:value-of select="$pb"/>
      </xsl:if>
      <!-- UnorderedGroup(Indexed) and OrderedGroup(Indexed): recurse -->
      <xsl:if test="contains(local-name(.), 'Group')">
        <xsl:call-template name="getrefs">
          <xsl:with-param name="group" select="."/>
        </xsl:call-template>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
  <!-- override implicit rules copying elements and attributes: -->
  <xsl:template match="text()"/>
</xsl:stylesheet>

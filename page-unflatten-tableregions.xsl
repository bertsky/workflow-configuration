<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  <xsl:preserve-space elements="*"/>
  <!-- LAREX cannot present/edit recursive regions, but TableRegion necessitates TextRegion for content
       so this moves TextRegion elements previously moved from TableRegion back to TableRegion/TextRegion -->
  <xsl:template match="pc:TableRegion">
    <xsl:variable name="tabid" select="@id"/>
    <xsl:copy>
      <xsl:apply-templates select="@* | node() | text()"/>
      <xsl:for-each select="../pc:TextRegion[concat('parent:',$tabid)=@custom]">
        <xsl:copy>
          <xsl:apply-templates select="@*[not(starts-with(.,'parent:'))]"/>
          <xsl:apply-templates select="node() | text()"/>
        </xsl:copy>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="pc:TextRegion[starts-with(@custom,'parent:')]"/>
  <xsl:template match="@* | node() | text()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node() | text()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>


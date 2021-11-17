<xsl:stylesheet version="1.0" 
xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
<xsl:preserve-space elements="*"/>

<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

<xsl:template match="*[namespace-uri()=/*/namespace::*[not(name())]]">
  <xsl:element name="{local-name()}" namespace="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
    <xsl:apply-templates select="@*|node()"/>
  </xsl:element>
</xsl:template>
<xsl:template match="//@xsi:schemaLocation">
  <xsl:attribute name="xsi:schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">
    <xsl:text>http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15 http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15/pagecontent.xsd</xsl:text>
    </xsl:attribute>
</xsl:template>

</xsl:stylesheet>

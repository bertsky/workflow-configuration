<xsl:stylesheet
    version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <!-- rename segments with @id clashes -->
  <xsl:key name="segments" match="pc:TextRegion|pc:TableRegion|pc:TextLine|pc:Word" use="@id" />
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  <xsl:template match="pc:TextRegion[generate-id() != generate-id(key('segments', @id)[1])]">
    <xsl:variable name="newID" select="generate-id()" />
    <xsl:element name="pc:TextRegion">
      <xsl:attribute name="id">
        <xsl:value-of select="$newID" />
      </xsl:attribute>
      <xsl:copy-of select="@*[not(local-name()='id')]"/>
      <xsl:copy-of select="*|text()"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="pc:TextLine[generate-id() != generate-id(key('segments', @id)[1])]">
    <xsl:variable name="newID" select="generate-id()" />
    <xsl:element name="pc:TextLine">
      <xsl:attribute name="id">
        <xsl:value-of select="$newID" />
      </xsl:attribute>
      <xsl:copy-of select="@*[not(local-name()='id')]"/>
      <xsl:copy-of select="*|text()"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="pc:Word[generate-id() != generate-id(key('segments', @id)[1])]">
    <xsl:variable name="newID" select="generate-id()" />
    <xsl:element name="pc:Word">
      <xsl:attribute name="id">
        <xsl:value-of select="$newID" />
      </xsl:attribute>
      <xsl:copy-of select="@*[not(local-name()='id')]"/>
      <xsl:copy-of select="*|text()"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="pc:Glyph[generate-id() != generate-id(key('segments', @id)[1])]">
    <xsl:variable name="newID" select="generate-id()" />
    <xsl:element name="pc:Glyph">
      <xsl:attribute name="id">
        <xsl:value-of select="$newID" />
      </xsl:attribute>
      <xsl:copy-of select="@*[not(local-name()='id')]"/>
      <xsl:copy-of select="*|text()"/>
    </xsl:element>
  </xsl:template>
  <xsl:template match="pc:TableRegion[generate-id() != generate-id(key('segments', @id)[1])]">
    <xsl:variable name="newID" select="generate-id()" />
    <xsl:element name="pc:TableRegion">
      <xsl:attribute name="id">
        <xsl:value-of select="$newID" />
      </xsl:attribute>
      <xsl:copy-of select="@*[not(local-name()='id')]"/>
      <xsl:copy-of select="*|text()"/>
    </xsl:element>
  </xsl:template>
</xsl:stylesheet>

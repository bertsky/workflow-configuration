<?xml version="1.0"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pc="http://schema.primaresearch.org/PAGE/gts/pagecontent/2019-07-15" xmlns:exslt="http://exslt.org/common" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" extension-element-prefixes="exslt">
  <xsl:output omit-xml-declaration="no" indent="yes" method="xml" encoding="utf-8"/>
  <xsl:template match="//pc:Coords/@points[contains(.,'-')]">
    <xsl:attribute name="points">
      <xsl:call-template name="convertpoints">
        <xsl:with-param name="text" select="string(.)"/>
      </xsl:call-template>
    </xsl:attribute>
  </xsl:template>
  <xsl:template name="convertpoints">
    <xsl:param name="text"/>
    <xsl:choose>
      <xsl:when test="not(contains($text,' '))">
        <xsl:call-template name="convertpoint">
          <xsl:with-param name="text" select="$text"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="convertpoint">
          <xsl:with-param name="text" select="substring-before($text,' ')"/>
        </xsl:call-template>
        <xsl:text> </xsl:text>
        <xsl:call-template name="convertpoints">
          <xsl:with-param name="text" select="substring-after($text,' ')"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template name="convertpoint">
    <xsl:param name="text"/>
    <xsl:call-template name="convertint">
      <xsl:with-param name="val" select="number(substring-before($text,','))"/>
    </xsl:call-template>
    <xsl:text>,</xsl:text>
    <xsl:call-template name="convertint">
      <xsl:with-param name="val" select="number(substring-after($text,','))"/>
    </xsl:call-template>
  </xsl:template>
  <xsl:template name="convertint">
    <xsl:param name="val"/>
    <xsl:choose>
      <xsl:when test="$val &lt; 0">
        <xsl:text>0</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="string($val)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="@*|node()" name="identity">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>

<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:t2m="http://tei-to-manuforma-form"
  exclude-result-prefixes="xs"
  version="2.0">
  
  <!--
    Convert TEI into a TEI like format suitable for use by a manuForma form
    @author Adam Retter
  -->

  <!--
    Parameter for labels to be added for tei:relation elements.
    Should have the format:

    <labels>
      <label ref="ref-1"><text>label-1</text></label>
      <label ref="ref-2"><text>label-2</text></label>
    </labels>    
  -->
  <xsl:param name="labels" as="element(labels)?" required="no"/>
  
  
  <xsl:import href="tei-to-markdown.xslt"/>
  
  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>
  
  
  <xsl:template match="tei:TEI">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Replace container elements that have no text with empty container elements -->
  <xsl:template match="tei:note[empty(descendant::text())]|tei:summary[not(parent::tei:layoutDesc)][empty(descendant::text())]|tei:quote[empty(descendant::text())]" priority="2">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
   </xsl:copy>
  </xsl:template>
  
  <!-- Convert children of container elements to TEI Markdown form -->
  <xsl:template match="tei:note|tei:summary[not(parent::tei:layoutDesc)]|tei:quote">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()" mode="tei-to-markdown"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Convert tei:relation elements to tei:active, tei:mutual, or tei:passive elements -->
  <xsl:template match="tei:relation[exists((@active, @mutual, @passive))]">
    <xsl:variable name="relation" select="."/>
    <xsl:for-each select="('active', 'mutual', 'passive')">
      <xsl:variable name="attr-name" as="xs:string" select="."/>
      <xsl:for-each select="tokenize($relation/@*[local-name(.) eq $attr-name], ' ')[. ne '']">
        <xsl:variable name="ref" as="xs:string" select="."/>
        <xsl:variable name="label" as="text()?" select="$labels/label[@ref eq $ref]/text/text()"/>
        <xsl:element name="tei:{$attr-name}">
          <xsl:attribute name="ref" select="$ref"/>
          <xsl:apply-templates select="$relation/@*[not(name(.) = ('active', 'mutual', 'passive'))]"/>
          <xsl:copy-of select="$label"/>
        </xsl:element>
      </xsl:for-each>
    </xsl:for-each>
  </xsl:template>
  
  <!-- Default: Normalize space in text nodes -->
  <xsl:template match="text()" priority="-1">
    <xsl:value-of select="normalize-space(.)"/>
  </xsl:template>
  
  <!-- Default: Identity trasform everything whilst updating the 'source' attribute -->
  <xsl:template match="node()|@*" priority="-2">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>

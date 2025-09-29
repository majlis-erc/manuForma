<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:t2m="http://tei-2-markdown"
  exclude-result-prefixes="xs"
  version="2.0">

  <!--
    Convert TEI to Markdown for manuForma forms
    @author Adam Retter
  -->

  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>


  <xsl:template name="tei-to-markdown">
    <xsl:apply-templates select="." mode="tei-to-markdown"/>
  </xsl:template>
  
  <!-- Replace tei:hi h1 Elements with heading 1 Markdown -->
  <xsl:template match="tei:hi[@rend eq 'h1']" mode="tei-to-markdown">
    <xsl:variable name="children" as="node()*">
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:variable>
    <xsl:text># </xsl:text><xsl:sequence select="t2m:trim-text($children)"/><xsl:text>&#xa;</xsl:text>
  </xsl:template>
  
  <!-- Replace tei:hi h2 Elements with heading 2 Markdown -->
  <xsl:template match="tei:hi[@rend eq 'h2']" mode="tei-to-markdown">
    <xsl:variable name="children" as="node()*">
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:variable>
    <xsl:text>## </xsl:text><xsl:apply-templates select="t2m:trim-text($children)" mode="#current"/><xsl:text>&#xa;</xsl:text>
  </xsl:template>
  
  <!-- Replace tei:hi h3 Elements with heading 3 Markdown -->
  <xsl:template match="tei:hi[@rend eq 'h3']" mode="tei-to-markdown">
    <xsl:variable name="children" as="node()*">
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:variable>
    <xsl:text>### </xsl:text><xsl:apply-templates select="t2m:trim-text($children)" mode="#current"/><xsl:text>&#xa;</xsl:text>
  </xsl:template>
  
  <!-- Replace tei:hi h1, h2, h3 Elements that contain only whitespace with a single space character -->
  <xsl:template match="tei:hi[@rend = ('h1', 'h2', 'h3')][matches(., '^\s+$')]" mode="tei-to-markdown" priority="2">
    <xsl:text> </xsl:text>
  </xsl:template>
  
  <!-- Drop empty tei:hi Elements -->
  <xsl:template match="tei:hi[empty(child::node())]" mode="tei-to-markdown" priority="2"/>
  
  <!-- Replace tei:emph bold Elements with bold Markdown -->
  <xsl:template match="tei:emph[@rend eq 'bold']" mode="tei-to-markdown">
    <xsl:text>**</xsl:text><xsl:apply-templates select="node()" mode="#current"/><xsl:text>**</xsl:text>
  </xsl:template>
  
  <!-- Replace tei:emph italic Elements with italic Markdown -->
  <xsl:template match="tei:emph[@rend eq 'italic']" mode="tei-to-markdown">
    <xsl:text>*</xsl:text><xsl:apply-templates select="node()" mode="#current"/><xsl:text>*</xsl:text>
  </xsl:template>
  
  <!-- Replace tei:emph bold or italic Elements that contain only whitespace with a single space character -->
  <xsl:template match="tei:emph[@rend = ('bold', 'italic')][matches(., '^\s+$')]" mode="tei-to-markdown" priority="2">
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- Replace tei:emph non-bold and non-italic elements with children --> 
  <xsl:template match="tei:emph[not(@rend = ('bold', 'italic'))]" mode="tei-to-markdown">
    <xsl:apply-templates select="node()" mode="#current"/>
  </xsl:template>
  
  <!-- Drop empty tei:emph Elements -->
  <xsl:template match="tei:emph[empty(child::node())]" mode="tei-to-markdown" priority="2"/>
  
  <!-- Replace runs of whitespace between tei:emph Elements with a single space character -->
  <xsl:template match="text()[preceding-sibling::tei:emph][following-sibling::tei:emph][matches(., '^\s+$')]" mode="tei-to-markdown">
    <xsl:text> </xsl:text>
  </xsl:template>

  <!-- Remove space characters in text that occur before and after tei:lb Elements -->
  <xsl:template match="text()[ends-with(., ' ')][following-sibling::tei:lb][starts-with(., ' ')][preceding-sibling::tei:lb]" mode="tei-to-markdown" priority="3">
    <xsl:value-of select="normalize-space(replace(replace(replace(replace(., '^(.*)\s+$', '$1'), '^\s+(.*)$', '$1'), '^\s+(.*)$', '$1'), '^(.*)\s+$', '$1'))"/>
  </xsl:template>

  <!-- Remove space characters in text that occur before tei:lb Elements -->
  <xsl:template match="text()[ends-with(., ' ')][following-sibling::tei:lb]" mode="tei-to-markdown" priority="2">
    <xsl:value-of select="normalize-space(replace(replace(., '^(.*)\s+$', '$1'), '^\s+(.*)$', '$1'))"/>
  </xsl:template>
  
  <!-- Remove space characters in text that occur after tei:lb Elements -->
  <xsl:template match="text()[starts-with(., ' ')][preceding-sibling::tei:lb]" mode="tei-to-markdown">
    <xsl:value-of select="normalize-space(replace(replace(., '^\s+(.*)$', '$1'), '^(.*)\s+$', '$1'))"/>
  </xsl:template>

  <!-- Replace tei:lb Elements with a line-break character when they have a following sibling (that is not a tei:lb) -->
  <xsl:template match="tei:lb[following-sibling::node()[not(self::tei:lb)]]" mode="tei-to-markdown">
    <xsl:text>&#xa;</xsl:text>
  </xsl:template>
  
  <!-- Drop tei:lb Elements when they do not have a following sibling -->
  <xsl:template match="tei:lb[empty(following-sibling::node())]" mode="tei-to-markdown"/>

  <!-- Separate tei:p Elements with a single line-break character (i.e.: '\n') --> 
  <xsl:template match="tei:p[following-sibling::tei:p]" mode="tei-to-markdown">
    <xsl:apply-templates select="node()|@*" mode="#current"/>
    <xsl:text>&#xa;&#xa;</xsl:text>
  </xsl:template>

  <!-- Remove unknown Element tags -->
  <xsl:template match="element()" mode="tei-to-markdown">
    <xsl:apply-templates select="node()|@*" mode="#current"/>
  </xsl:template>
  
  <!-- Convert unknown Attributes into Text -->
  <xsl:template match="attribute()" mode="tei-to-markdown">
    <xsl:value-of select="name(.)"/><xsl:text>: </xsl:text><xsl:value-of select="."/>
  </xsl:template>
  
  <!-- Default: Cleanup text nodes -->
  <xsl:template match="text()" mode="tei-to-markdown" priority="-3">
    <xsl:value-of select="replace(replace(., '\s*&#xD;(&#xA;)?\s*', '&#xA;'), '^&#xA;*(.+)&#xA;*$', '$1')"/>
  </xsl:template>

  <!-- Default: Identity transform everything except Elements (which will be dealt with above) --> 
  <xsl:template match="node()[not(. instance of element())]|@*" mode="tei-to-markdown" priority="-4">
    <xsl:copy>
      <xsl:apply-templates select="node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:function name="t2m:trim-text" as="node()*">
    <xsl:param name="input" required="yes" as="node()*"/>
    <xsl:variable name="length" select="count($input)"/>
    <xsl:choose>
      <xsl:when test="$length eq 1">
        <xsl:value-of select="normalize-space($input)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="t2m:trim-text-replace(head($input), '^\s*(.+)$')"/>
        <xsl:sequence select="subsequence($input, 2, $length - 1)"/>
        <xsl:sequence select="t2m:trim-text-replace($input[$length], '^(.+)\s*$')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="t2m:trim-text-replace" as="node()?">
    <xsl:param name="node" as="node()?"/>
    <xsl:param name="extract-pattern" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$node instance of text()">
        <xsl:value-of select="replace($node, $extract-pattern, '$1')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="$node"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
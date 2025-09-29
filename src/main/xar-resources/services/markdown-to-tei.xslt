<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:m2t="http://markdown-2-tei"
  exclude-result-prefixes="xs m2t"
  version="2.0">

  <!--
    Convert Markdown to TEI from manuForma forms
    @author Adam Retter
  -->

  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>


  <xsl:template name="markdown-to-tei">
    <xsl:apply-templates select="." mode="markdown-to-tei"/>
  </xsl:template>

  <!-- Replace heading 1 Markdown with tei:hi h1 Element -->
  <xsl:template match="text()[matches(., '(^|[^#])#\s+.+')]" mode="markdown-to-tei">
    <xsl:sequence select="m2t:h1(.)"/>
  </xsl:template>

  <!-- Replace heading 2 Markdown with tei:hi h2 Element -->
  <xsl:template match="text()[matches(., '(^|[^#])##\s+.+')]" mode="markdown-to-tei">
    <xsl:sequence select="m2t:h2(.)"/>
  </xsl:template>

  <!-- Replace heading 3 Markdown with tei:hi h3 Element -->
  <xsl:template match="text()[matches(., '(^|[^#])###\s+.+')]" mode="markdown-to-tei">
    <xsl:sequence select="m2t:h3(.)"/>
  </xsl:template>

  <!-- Replace bold Markdown with tei:emph bold Element -->
  <xsl:template match="text()[matches(., '\*\*([^*]+)\*\*')]" mode="markdown-to-tei">
    <xsl:sequence select="m2t:bold(.)"/>
  </xsl:template>

  <!-- Replace italic Markdown with tei:emph italic Element -->
  <xsl:template match="text()[matches(., '(^|[^*\\])\*[^*]*[^*\\]\*([^*]|$)')]" mode="markdown-to-tei">
    <xsl:sequence select="m2t:italic(.)"/>
  </xsl:template>

  <!-- Process Markdown paragraphs and convert them into tei:hi and tei:p Elements -->
  <xsl:template match="text()" mode="markdown-to-tei-container">
    <!-- First we normalize the line endings -->
    <xsl:variable name="text-with-normalized-line-endings" select="m2t:normalize-line-endings(.)"/>

    <!-- Second we split on /n/n+ whilst ignoring misc whitespace to create headings or paragraphs -->
    <xsl:variable name="paragraphs" as="xs:string*" select="tokenize($text-with-normalized-line-endings, '\n[ \t\r]*\n+')[not(matches(., '^[ \t\r]+$'))][string-length(.) gt 0]"/>
    <xsl:for-each select="$paragraphs">
      <xsl:variable name="paragraph" as="xs:string" select="."/>
      
      <!-- We now split on /n whilst ignoring misc whitespace to create lines from the paragraph -->
      <xsl:variable name="lines" as="xs:string*" select="tokenize($paragraph, '\n')[not(matches(., '^[ \t\r]+$'))][string-length(.) gt 0]"/>
      <xsl:variable name="first-line" as="xs:string?" select="m2t:trim(head($lines))"/>
      <xsl:variable name="remaining-lines" as="xs:string*" select="tail($lines) ! m2t:trim(.)"/>
      
      <xsl:choose>
        <xsl:when test="matches($first-line, '^#\s+.+')">
          <!-- First line is a Markdown heading 1, so process that and then the remaining lines make up the paragraph -->
          <xsl:sequence select="m2t:h1($first-line)"/>
          <xsl:sequence select="m2t:paragraph($remaining-lines)"/>
        </xsl:when>
        
        <xsl:when test="matches($first-line, '^##\s+.+')">
          <!-- First line is a Markdown heading 2, so process that and then the remaining lines make up the paragraph -->
          <xsl:sequence select="m2t:h2($first-line)"/>
          <xsl:sequence select="m2t:paragraph($remaining-lines)"/>
        </xsl:when>
        
        <xsl:when test="matches($first-line, '^###\s+.+')">
          <!-- First line is a Markdown heading 3, so process that and then the remaining lines make up the paragraph -->
          <xsl:sequence select="m2t:h3($first-line)"/>
          <xsl:sequence select="m2t:paragraph($remaining-lines)"/>
        </xsl:when>
        
        <xsl:otherwise>
          <!-- First line is just text, so all lines make up the paragraph -->
          <xsl:sequence select="m2t:paragraph(($first-line, $remaining-lines))"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Drop empty tei:title elements -->
  <xsl:template match="tei:title[empty((text(), @ref)[normalize-space(.) ne ''])]" mode="markdown-to-tei"/>

  <!-- Replace non-TEI elements with tei:p if they don't have an ancestor tei:p -->
  <xsl:template match="element()[namespace-uri(.) ne 'http://www.tei-c.org/ns/1.0'][empty(ancestor::tei:p)]" mode="markdown-to-tei">
    <tei:p>
      <xsl:for-each select="node()">
        <xsl:choose>
          <xsl:when test=". instance of element() and namespace-uri(.) ne 'http://www.tei-c.org/ns/1.0'">
            <xsl:apply-templates select="./node()" mode="non-tei-container"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="non-tei-container"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </tei:p>
  </xsl:template>

  <!-- Drop non-TEI elements if they have an ancestor tei:p -->
  <xsl:template match="element()[namespace-uri(.) ne 'http://www.tei-c.org/ns/1.0'][ancestor::tei:p]" mode="markdown-to-tei">
    <xsl:for-each select="node()">
      <xsl:choose>
        <xsl:when test=". instance of element() and namespace-uri(.) ne 'http://www.tei-c.org/ns/1.0'">
          <xsl:apply-templates select="./node()" mode="non-tei-container"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="." mode="non-tei-container"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Used above to replace non-TEI elements with tei:p --> 
  <xsl:template match="node()|@*" mode="non-tei-container">
    <xsl:copy>
      <xsl:for-each select="node()|@*">
        <xsl:choose>
          <xsl:when test=". instance of element() and namespace-uri(.) ne 'http://www.tei-c.org/ns/1.0'">
            <xsl:apply-templates select="./node()" mode="#current"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="#current"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>

  <!-- Default: Identity trasform everything --> 
  <xsl:template match="node()|@*" mode="markdown-to-tei" priority="-3">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:function name="m2t:paragraph" as="node()*">
    <xsl:param name="lines" as="item()*" required="yes"/>
    <xsl:if test="exists($lines)">
      <tei:p>
        <xsl:for-each select="(1 to count($lines))">
          <xsl:variable name="i" select="." as="xs:integer"/>
          <xsl:variable name="line" select="$lines[$i]"/>
          <xsl:if test="$i gt 1"><tei:lb/></xsl:if>
          <xsl:sequence select="m2t:bold-and-italic($line)"/>
        </xsl:for-each>
      </tei:p>
    </xsl:if>
  </xsl:function>

  <xsl:function name="m2t:h1" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:analyze-string select="$markdown" regex="(^|[^#])#\s+(.+)">
      <xsl:matching-substring>
        <xsl:if test="m2t:non-empty(regex-group(1))"><xsl:value-of select="regex-group(1)"/></xsl:if><tei:hi rend="h1"><xsl:sequence select="m2t:bold-and-italic(normalize-space(regex-group(2)))"/></tei:hi>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="m2t:h2" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:analyze-string select="$markdown" regex="(^|[^#])##\s+(.+)">
      <xsl:matching-substring>
        <xsl:if test="m2t:non-empty(regex-group(1))"><xsl:value-of select="regex-group(1)"/></xsl:if><tei:hi rend="h2"><xsl:sequence select="m2t:bold-and-italic(normalize-space(regex-group(2)))"/></tei:hi>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="m2t:h3" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:analyze-string select="$markdown" regex="(^|[^#])###\s+(.+)">
      <xsl:matching-substring>
        <xsl:if test="m2t:non-empty(regex-group(1))"><xsl:value-of select="regex-group(1)"/></xsl:if><tei:hi rend="h3"><xsl:sequence select="m2t:bold-and-italic(normalize-space(regex-group(2)))"/></tei:hi>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="m2t:bold" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:analyze-string select="$markdown" regex="(^|[^\\])\*\*([^*]*[^*\\])\*\*">
      <xsl:matching-substring>
        <xsl:if test="m2t:non-empty(regex-group(1))"><xsl:value-of select="regex-group(1)"/></xsl:if><tei:emph rend="bold"><xsl:value-of select="regex-group(2)"/></tei:emph>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="m2t:italic" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:analyze-string select="$markdown" regex="(^|[^*\\])\*([^*]*[^*\\])\*([^*]|$)">
      <xsl:matching-substring>
        <xsl:if test="m2t:non-empty(regex-group(1))"><xsl:value-of select="regex-group(1)"/></xsl:if><tei:emph rend="italic"><xsl:value-of select="regex-group(2)"/></tei:emph><xsl:if test="m2t:non-empty(regex-group(3))"><xsl:value-of select="regex-group(3)"/></xsl:if>
      </xsl:matching-substring>
      <xsl:non-matching-substring>
        <xsl:value-of select="."/>
      </xsl:non-matching-substring>
    </xsl:analyze-string>
  </xsl:function>

  <xsl:function name="m2t:bold-and-italic" as="node()+">
    <xsl:param name="markdown" required="yes"/>
    <xsl:variable name="after-bold" select="for $x in $markdown return if ($x instance of text() or $x instance of xs:string) then m2t:bold($x) else $x"/>
    <xsl:variable name="after-italic" select="for $x in $after-bold return if ($x instance of text() or $x instance of xs:string) then m2t:italic($x) else $x"/>
    <xsl:sequence select="$after-italic"/>
  </xsl:function>

  <xsl:function name="m2t:non-empty" as="xs:string*">
    <xsl:param name="inputs" as="xs:string*" required="yes"/>
    <xsl:sequence select="$inputs[string-length(.) gt 0]"/>
  </xsl:function>

  <xsl:function name="m2t:normalize-line-endings" as="text()">
    <xsl:param name="text" as="text()" required="yes"/>
    <xsl:variable name="text-with-normalized-line-endings" select="replace($text, '&#xD;(&#xA;)?', '&#xA;')"/>
    <xsl:variable name="trimmed-text" select="m2t:trim($text-with-normalized-line-endings)"/>
    <xsl:value-of select="$trimmed-text"/>
  </xsl:function>

  <xsl:function name="m2t:trim" as="text()">
    <xsl:param name="text" required="yes"/>
    <!-- xsl:variable name="trimmed-text" select="replace($text, '^&#x20;*(.+)&#x20;*$', '$1')"/ -->
    <xsl:variable name="trimmed-text" select="replace($text, '^&#x20;+|&#x20;+$', '')"/>
    <xsl:value-of select="$trimmed-text"/>
  </xsl:function>

</xsl:stylesheet>
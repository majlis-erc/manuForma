<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:tei="http://www.tei-c.org/ns/1.0"
  xmlns:m2t="http://manuforma-form-to-tei"
  exclude-result-prefixes="xs"
  version="2.0">

  <!--
    Convert TEI like submission from a manuForma form to TEI
    @author Adam Retter
  -->

  <xsl:param name="new" as="xs:boolean" select="false()"/>
  <xsl:param name="id" as="xs:string" required="yes"/>
  <xsl:param name="uri" as="xs:string?" required="yes"/>
  <xsl:param name="user-id" as="xs:string" select="'guest'"/>
  <xsl:param name="user-name" as="xs:string" select="'Guest'"/>


  <xsl:import href="markdown-to-tei.xslt"/>

  <xsl:output method="xml" version="1.0" omit-xml-declaration="no" encoding="UTF-8" indent="yes"/>


  <xsl:template match="tei:TEI">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*[local-name() ne 'class']"/>
    </xsl:copy>
  </xsl:template>

  <!-- Elements that match this template are Markdown containers -->
  <xsl:template match="tei:note|tei:summary[not(parent::tei:layoutDesc)]|tei:quote">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:for-each select="node()">
        <xsl:choose>
          <xsl:when test=". instance of text()">
            <xsl:apply-templates select="." mode="markdown-to-tei-container"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="." mode="markdown-to-tei"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:ab[@type eq 'factoid'][@subtype eq 'relation']">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('factoid-', $id)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Add a Contributor into the titleStmt Element --> 
  <xsl:template match="tei:titleStmt">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="tei:title,tei:author,tei:sponsor,tei:funder,tei:principal"/>
      <xsl:apply-templates select="tei:editor[exists((text(), @ref)[normalize-space(.) ne ''])]"/>
      <xsl:if test="$user-id ne 'guest' and empty(tei:editor[. eq $user-name])">
        <tei:editor xml:id="{$user-id}" role="contributor"><xsl:value-of select="$user-name"/></tei:editor>
      </xsl:if>
      <xsl:apply-templates select="tei:meeting,tei:respStmt"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:idno[parent::tei:ab[@type eq 'factoid'][@subtype eq 'relation']]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('name-', count(preceding-sibling::tei:idno) + 1)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:idno[parent::tei:publicationStmt]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:choose>
        <xsl:when test="$new">
          <xsl:choose>
            <xsl:when test="starts-with($uri, .)">
              <xsl:value-of select="$uri"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="node()"/>
              <xsl:value-of select="$uri"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:place[parent::tei:listPlace]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('place-', $id)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:placeName[parent::tei:place/parent::tei:listPlace]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('name-', count(preceding-sibling::tei:placeName) + 1)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:bibl[parent::tei:place/parent::tei:listPlace or parent::tei:person/parent::tei:listPerson or parent::tei:bibl/parent::tei:bibl/parent::tei:body]">
    <xsl:copy>
      <xsl:apply-templates select="@*[name(.) ne 'source']"/>
      <!-- xsl:attribute name="xml:id" select="concat('bibl-', count(preceding-sibling::tei:bibl) + 1)"/ -->
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:bibl[parent::tei:body/parent::tei:text]">
    <xsl:copy>
      <xsl:apply-templates select="@*[name(.) ne 'source']"/>
      <!-- xsl:attribute name="xml:id" select="concat('work-', $id)"/ -->
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:bibl[parent::tei:listBibl/parent::tei:additional/parent::tei:msDesc]">
    <xsl:copy>
      <xsl:apply-templates select="@*[name(.) ne 'source']"/>
      <!-- xsl:attribute name="xml:id" select="concat('bibl-', (count(parent::tei:listBibl/parent::tei:additional/preceding-sibling::tei:additional) + 1), '.', (count(parent::tei:listBibl/preceding-sibling::tei:listBibl) + 1), '.', (count(preceding-sibling::tei:bibl) + 1))"/ -->
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="tei:title[parent::tei:bibl/parent::tei:body]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('title-', count(preceding-sibling::tei:title) + 1)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Drop empty title elements -->
  <xsl:template match="tei:title[empty((text(), @ref)[normalize-space(.) ne ''])]" priority="2"/>

  <xsl:template match="tei:person[parent::tei:listPerson]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('person-', $id)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:persName[parent::tei:person/parent::tei:listPerson]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('name-', count(preceding-sibling::tei:persName) + 1)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:msDesc[parent::tei:person/parent::tei:listPerson]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('ms-', $id)"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:msItem[parent::tei:msContents/parent::tei:msDesc]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('item-', (count(parent::tei:msContents/preceding-sibling::tei:msContents) + 1), '.', (count(preceding-sibling::tei:msItem) + 1))"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:layout[parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/parent::tei:msDesc]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('layout-', (count(parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1), '.', (count(parent::tei:layoutDesc/parent::tei:objectDesc/preceding-sibling::tei:objectDesc) + 1), '.', (count(parent::tei:layoutDesc/preceding-sibling::tei:layoutDesc) + 1), '.', (count(preceding-sibling::tei:layout) + 1))"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:handNote[parent::tei:handDesc/parent::tei:physDesc/parent::tei:msDesc]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('hand-', (count(parent::tei:handDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1), '.', (count(parent::tei:handDesc/preceding-sibling::tei:handDesc) + 1), '.', (count(preceding-sibling::tei:handNote) + 1))"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:item[parent::tei:list/parent::tei:additions/parent::tei:physDesc/parent::tei:msDesc]">
    <xsl:call-template name="copy-with-updated-id-and-source">
      <xsl:with-param name="id" select="concat('add-', (count(parent::tei:list/parent::tei:additions/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1), '.', (count(parent::tei:list/parent::tei:additions/preceding-sibling::tei:additions) + 1), '.', (count(parent::tei:list/preceding-sibling::tei:list) + 1), '.', (count(preceding-sibling::tei:item) + 1))"/>
      <xsl:with-param name="source" select="m2t:extract-source(@source)"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="tei:relation[exists((tei:active, tei:mutual, tei:passive))]">
    <xsl:copy>
      <xsl:apply-templates select="@*[not(name(.) = ('active', 'mutual', 'passive'))]"/>
      <xsl:if test="tei:active/@ref">
        <xsl:attribute name="active" select="string-join(tei:active/@ref, ' ')"/>
      </xsl:if>
      <xsl:if test="tei:mutual/@ref">
        <xsl:attribute name="mutual" select="string-join(tei:mutual/@ref, ' ')"/>
      </xsl:if>
      <xsl:if test="tei:passive/@ref">
        <xsl:attribute name="passive" select="string-join(tei:passive/@ref, ' ')"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>

  <xsl:function name="m2t:extract-source" as="xs:string?">
    <xsl:param name="input" as="xs:string?" required="yes"/>
    <xsl:if test="exists($input)">
      <xsl:sequence select="concat('#', tokenize($input, '#')[last()])"/>
    </xsl:if>
  </xsl:function>

  <!-- Copies an element whilst adding or replacing its 'xml:id' and 'source' attributes -->
  <xsl:template name="copy-with-updated-id-and-source">
    <xsl:param name="id" as="xs:string" required="yes"/>
    <xsl:param name="source" as="xs:string?" required="yes"/>
    <xsl:copy>
      <xsl:attribute name="xml:id" select="$id"/>
      <xsl:if test="exists($source)">
        <xsl:attribute name="source" select="$source"/>
      </xsl:if>
      <xsl:apply-templates select="@*[not(name(.) = ('xml:id', 'source'))]|node()"/>
    </xsl:copy>
  </xsl:template>


  <!-- Default: Identity trasform everything whilst updating the 'source' attribute -->
  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="@*[name(.) ne 'source']"/>
      <xsl:if test="@source[. ne '']">
        <xsl:attribute name="source" select="concat('#', substring-after(@source, '#'))"/>
      </xsl:if>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
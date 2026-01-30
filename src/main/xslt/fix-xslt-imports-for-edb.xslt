<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0">
  
  <!-- The collection path URI in the database where the xsl:import can be resolved from -->  
  <xsl:param name="db-collection-uri" as="xs:string" required="yes"/> 

  <xsl:template match="xsl:import">
    <xsl:copy>
      <xsl:attribute name="href" select="concat($db-collection-uri, '/', @href)"/>
      <xsl:apply-templates select="node()|@*[local-name(.) ne 'href']"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Default: Identity trasform everything -->
  <xsl:template match="node()|@*">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0">
    
    <xsl:template match="/">
        <html>
            <body>
                <h2>manuForma TEI Tool Tips</h2>
                <table border="1">
                    <tr bgcolor="#9acd32">
                        <th>manuForma field</th>
                        <th>Explanation</th>
                        <th>TEI element</th>
                    </tr>
                    <xsl:for-each select="//tei:schemaSpec/tei:elementSpec">
                        <tr>
                            <td><xsl:value-of select="tei:gloss"/></td>
                            <td><xsl:value-of select="tei:desc"/></td>
                            <td><xsl:value-of select="./@ident"/></td>
                        </tr>
                    </xsl:for-each>
                </table>
            </body>
        </html>
    </xsl:template>
    
</xsl:stylesheet>
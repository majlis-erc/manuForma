<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="xml" omit-xml-declaration="yes"/>
    <xsl:template match="/">
        <div style="margin-right:1.5em">
            <xsl:apply-templates/>
        </div>
    </xsl:template>
    <xsl:template match="processing-instruction()">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <span style="color:blue">&lt;?</span>
            <span style="color:blue"><xsl:value-of select="name()"/> <xsl:value-of select="."/></span>
            <span style="color:blue">?&gt;</span>
        </div>
    </xsl:template>
    <xsl:template match="@*" xml:space="preserve">
						<span style="color:red"> <xsl:value-of select="name()"/></span>
						<span style="color:black">=</span>
						<span style="color:blue">"<b><xsl:value-of select="."/></b>"</span>
					</xsl:template>
    <xsl:template match="text()">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <span style="font-weight:bold">
                <xsl:value-of select="."/>
            </span>
        </div>
    </xsl:template>
    <xsl:template match="comment()">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <span style="color:blue">&lt;!--</span>
            <span style="color:#888888">
                <pre><xsl:value-of select="."/></pre>
            </span>
            <span style="color:blue">--&gt;</span>
        </div>
    </xsl:template>
    <xsl:template match="*">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <div style="margin-left:1em;text-indent:-2em">
                <span style="color:blue">&lt;<xsl:value-of select="name()"/></span>
                <xsl:apply-templates select="@*"/>
                <span style="color:blue">/&gt;</span>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="*[text() and not(comment() | processing-instruction())]">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <div style="margin-left:1em;text-indent:-2em">
                <span style="color:blue">&lt;<xsl:value-of select="name()"/></span>
                <xsl:apply-templates select="@*"/>
                <span style="color:blue">&gt;</span>
                <span style="font-weight:bold">
                    <xsl:value-of select="."/>
                </span>
                <span style="color:blue">&lt;/<xsl:value-of select="name()"/>&gt;</span>
            </div>
        </div>
    </xsl:template>
    <xsl:template match="*[*]">
        <div style="margin-left:1em; text-indent:-1em; margin-right:1em">
            <div style="margin-left:1em;text-indent:-2em">
                <span style="color:blue">&lt;<xsl:value-of select="name()"/></span>
                <xsl:apply-templates select="@*"/>
                <span style="color:blue">&gt;</span>
            </div>
            <div>
                <xsl:apply-templates/>
                <div>
                    <span style="color:blue">&lt;/<xsl:value-of select="name()"/>&gt;</span>
                </div>
            </div>
        </div>
    </xsl:template>
</xsl:stylesheet>
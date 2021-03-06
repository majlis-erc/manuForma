<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:sc="http://www.ascc.net/xml/schematron" xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xi="http://www.w3.org/2001/XInclude" xmlns:local="http://syriaca.org/ns"
    xmlns:srophe="https://srophe.app"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
    <!-- 
        Generate XForms from a schema. Designed for TEI XML creation and editing. Run as an eXist-db application. 
        Resulting TEI can be saved to eXist-db, downloaded to local filesystem, or saved to a GitHub repository
        
        Expectations: 
        
        Requirements: 
            - config.xml; see example
            - TEI template, example record
            - Local schema constrainst, such as an ODD file
            - Main schema as an ODD file
            - XSLTForms
            - eXist-db 
            
        Version: 0.01 Beta
        

        NOTES: 
          TEI macrRefs tend to lead to endless looping, especially plike and macro.phraseSeq
          Ignore or turn into simple p elements with a textNode only.  
            
           measure: macro.phraseSeq 
    -->
    <!-- 
        WS:Note better error handling, check to make sure all referenced schemas and templates are available
        create graceful fail and error reporting
    -->
    <!-- Default config file. Use config prameter at run time to change.  -->
    <xsl:param name="config" select="'config.xml'"/>
    
    <!-- Global Variables -->
    <!-- XForm configuration document from config prameter. Default is config.xml -->
    <xsl:variable name="configDoc" select="document($config)"/>
    
    <!-- Form languge from config file; default is en -->
    <xsl:variable name="formLang">
        <xsl:choose>
            <xsl:when test="$configDoc//formLang[. != '']">
                <xsl:value-of select="$configDoc//formLang"/>
            </xsl:when>
            <xsl:otherwise>en</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>
    
    <!-- For use with the eXist application, establishes the full path to the application -->
    <xsl:variable name="app-root" select="$configDoc//formURL[. != '']"/>
    
    <!-- Output as XForm or TEI record -->
    <xsl:output name="xform" encoding="UTF-8" method="xhtml" indent="yes" omit-xml-declaration="yes" xml:space="preserve" xpath-default-namespace="http://www.w3.org/1999/xhtml"/>
    <xsl:output name="tei" encoding="UTF-8" method="xml" indent="yes" xpath-default-namespace="http://www.tei-c.org/ns/1.0"/>

    <!-- Helper functions -->
    <!-- 
        Check local and global schemas for element rules 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->    
    <xsl:function name="local:elementRules">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localSchemaDoc//descendant-or-self::tei:elementSpec[@ident = $elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::tei:elementSpec[@ident = $elementName]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </global>
        </rules>
    </xsl:function>
    
    <!-- 
        Find all child elements for selected element, check local schema rules first, then global schema rules
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:childElements">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName, $subform)"/>
        <xsl:variable name="elementRefs">
            <xsl:variable name="rules">
                <xsl:choose>
                    <xsl:when test="$elementRules/tei:local/descendant-or-self::tei:content">
                        <xsl:copy-of select="$elementRules/tei:local"/>
                    </xsl:when>
                    <xsl:when test="$elementRules/tei:local/descendant-or-self::tei:alternate">
                        <xsl:copy-of select="$elementRules/tei:local"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$elementRules/tei:global"/>
                    </xsl:otherwise>
                </xsl:choose> 
            </xsl:variable>
            <xsl:for-each-group select="$rules/descendant-or-self::tei:content/descendant-or-self::*[@key] | $rules/descendant-or-self::tei:alternate/descendant-or-self::*[@key] " group-by="@key">
                    <xsl:choose>
                        <xsl:when test="(current-grouping-key() = ('macro.specialPara','model.pLike')) or (contains(current-grouping-key(),'macro.specialPara') or contains(current-grouping-key(),'model.pLike'))">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="p"/>
                        </xsl:when>
                        <xsl:when test="(current-grouping-key() = ('model.gLike','macro.xtext','macro.phraseSeq')) or (contains(current-grouping-key(),'macro.phraseSeq') or contains(current-grouping-key(),'macro.xtext') or contains(current-grouping-key(),'model.gLike'))"/>
                        <xsl:when test="contains(current-grouping-key(),'.')">
                            <xsl:choose>
                                <xsl:when test="contains(current-grouping-key(),'macro.')">
                                    <xsl:copy-of select="local:resolveMacroSpec(current-grouping-key(),$subform)"></xsl:copy-of> 
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:copy-of select="local:resolveClassRef(current-grouping-key(),$subform)"></xsl:copy-of>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{current-grouping-key()}"/>
                        </xsl:otherwise>
                    </xsl:choose>
            </xsl:for-each-group>    
        </xsl:variable>
        <child xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:copy-of select="$elementRefs"/>
        </child>
    </xsl:function>
    
    <!-- WS:Note may not be needed -->
    <xsl:function name="local:siblingElements">
        <xsl:param name="parentElementName"/>
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="elementRules" select="local:elementRules($parentElementName, $subform)"/>
        <xsl:variable name="elementRefs">
            <xsl:variable name="rules">
                <xsl:choose>
                    <xsl:when test="$elementRules/tei:local/descendant-or-self::tei:content">
                        <xsl:copy-of select="$elementRules/tei:local"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="$elementRules/tei:global"/>
                    </xsl:otherwise>
                </xsl:choose> 
            </xsl:variable>
            <xsl:for-each-group select="$rules/descendant-or-self::tei:content/descendant-or-self::*[@key]" group-by="@key">
                <xsl:choose>
                    <xsl:when test="current-grouping-key() = ('model.gLike','macro.xtext','macro.phraseSeq','macro.specialPara','model.pLike')">
                        <element xmlns="http://www.tei-c.org/ns/1.0" ident="p"/>
                    </xsl:when>
                    <xsl:when test="contains(current-grouping-key(),'.')">
                        <xsl:choose>
                            <xsl:when test="contains(current-grouping-key(),'macro.')">
                                <xsl:copy-of select="local:resolveMacroSpec(current-grouping-key(),$subform)"></xsl:copy-of> 
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy-of select="local:resolveClassRef(current-grouping-key(),$subform)"></xsl:copy-of>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <element xmlns="http://www.tei-c.org/ns/1.0" ident="{current-grouping-key()}"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>    
        </xsl:variable>
        <child xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:copy-of select="$elementRefs"/>
        </child>
    </xsl:function>
    
    <!-- 
        Find all child elements using memberOf references within an element specification. 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:resolveClassRef">
        <xsl:param name="className"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
        <xsl:variable name="localRules">
            <xsl:for-each select="$localSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                <xsl:choose>
                    <xsl:when test=".[@mode = 'delete']">
                        <element xmlns="http://www.tei-c.org/ns/1.0" class="deleted local"/>
                    </xsl:when>
                    <xsl:when test=".[@mode = 'change' or @mode = 'replace']">
                        <xsl:choose>
                            <xsl:when test="self::tei:elementSpec">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="local"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classSpec">
                                <xsl:variable name="subClassName" select="@ident"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                            </xsl:when>
                            <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>     
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localRules/descendant-or-self::tei:element">
                <xsl:copy-of select="$localRules"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc//descendant-or-self::*[tei:classes/tei:memberOf[@key = $className]]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="global"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classSpec">
                            <xsl:variable name="subClassName" select="@ident"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- 
        Find all child elements using macroSpec references within an element specification. 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:resolveMacroSpec">
        <xsl:param name="macroSpec"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
        <xsl:variable name="localRules">
            <xsl:for-each select="$globalSchemaDoc/descendant-or-self::tei:macroSpec[@ident = $macroSpec]/descendant-or-self::tei:content/descendant-or-self::*[@key]">
                <xsl:choose>
                    <xsl:when test=".[@mode = 'delete']">
                        <element xmlns="http://www.tei-c.org/ns/1.0" class="local deleted"/>
                    </xsl:when>
                    <xsl:when test=".[@mode = 'change' or @mode = 'replace']">
                        <xsl:choose>
                            <xsl:when test="self::tei:elementSpec">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="local"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classSpec">
                                <xsl:variable name="subClassName" select="@ident"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                            </xsl:when>
                            <xsl:when test="self::tei:classRef">
                                <xsl:variable name="subClassName" select="@key"/>
                                <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                            </xsl:when>
                            <xsl:when test="self::tei:elementRef">
                                <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@key)}" class="local">
                                    <xsl:copy-of select="."/>
                                </element>
                            </xsl:when>
                        </xsl:choose>
                    </xsl:when>
                </xsl:choose>  
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$localRules/descendant-or-self::tei:element">
                <xsl:copy-of select="$localRules"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:for-each select="$globalSchemaDoc/descendant-or-self::tei:macroSpec[@ident = $macroSpec]/descendant-or-self::tei:content/descendant-or-self::*[@key]">
                    <xsl:choose>
                        <xsl:when test="self::tei:elementSpec">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@ident)}" class="global"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classSpec">
                            <xsl:variable name="subClassName" select="@ident"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName,$subform)"/>
                        </xsl:when>
                        <xsl:when test="self::tei:classRef">
                            <xsl:variable name="subClassName" select="@key"/>
                            <xsl:copy-of select="local:resolveClassRef($subClassName, $subform)"/>
                        </xsl:when>
                        <xsl:when test="self::tei:elementRef">
                            <element xmlns="http://www.tei-c.org/ns/1.0" ident="{string(@key)}" class="global">
                                <xsl:copy-of select="."/>
                            </element>
                        </xsl:when>
                        <xsl:otherwise><xsl:value-of select="name(.)"/></xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    
    <!-- 
        Find all associated attributes of the specified element 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:classSpecAtt">
        <xsl:param name="className"/>
        <xsl:param name="subform"/>
        <xsl:variable name="localSchemaDoc" select="document($configDoc//subform[@formName = $subform]/localSchema/@src)"/>
        <xsl:variable name="globalSchemaDoc" select="document($configDoc//subform[@formName = $subform]/globalSchema/@src)"/>
        <xsl:variable name="localClasses" select="$localSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <xsl:variable name="globalClasses" select="$globalSchemaDoc//descendant-or-self::tei:classSpec[@ident = $className]"/>
        <rules xmlns="http://www.tei-c.org/ns/1.0">
            <local>
                <xsl:for-each select="$localClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$localClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf, $subform)"/>
                </xsl:for-each>
            </local>
            <global>
                <xsl:for-each select="$globalClasses/descendant-or-self::tei:attList/descendant-or-self::tei:attDef">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
                <xsl:variable name="memberOf" select="$globalClasses/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]/@key"/>
                <xsl:for-each select="$memberOf">
                    <xsl:copy-of select="local:classSpecAtt($memberOf,$subform)"/>
                </xsl:for-each>
            </global>
        </rules>
    </xsl:function>
    
    <!-- 
        Find all associated attributes of the specified element 
        @param: elementName - name of element to lookup in the schema
        @param: subform  - name of subform, for locating the correct local schema customizations
    -->
    <xsl:function name="local:allAttributes">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:variable name="elementRules" select="local:elementRules($elementName, $subform)"/>
        <xsl:variable name="childAtt" select="$elementRules/descendant-or-self::tei:attList"/>
        <xsl:variable name="childAttRef">
            <xsl:for-each select="$childAtt/descendant-or-self::tei:attRef">
                <attDef xmlns="http://www.tei-c.org/ns/1.0" ident="{@name}"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="memberOfAtt">
            <xsl:for-each-group select="$elementRules/descendant-or-self::tei:classes/tei:memberOf[starts-with(@key, 'att.')]" group-by="@key">
                <xsl:choose>
                    <xsl:when test=".[@mode='delete'][ancestor-or-self::tei:local]"></xsl:when>
                    <xsl:when test=".[@mode='change'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='change'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='opt'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='opt'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='add'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='add'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:when test=".[@mode='replace'][ancestor-or-self::tei:local]"><xsl:copy-of select="local:classSpecAtt(.[@mode='replace'][ancestor-or-self::tei:local][1]/@key,$subform)"/></xsl:when>
                    <xsl:otherwise><xsl:copy-of select="local:classSpecAtt(@key,$subform)"/></xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:variable>
        <availableAtts xmlns="http://www.tei-c.org/ns/1.0" elementName="{$elementName}">
            <xsl:for-each-group select="$childAtt/descendant-or-self::tei:attDef | $childAttRef/descendant-or-self::tei:attDef | $memberOfAtt/descendant-or-self::tei:attDef" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                    <xsl:choose>
                        <xsl:when test=".[@mode='delete'][ancestor-or-self::tei:local]"></xsl:when>
                        <xsl:when test=".[@mode='change'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='change'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='opt'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='opt'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='add'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='add'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:when test=".[@mode='replace'][ancestor-or-self::tei:local]"><xsl:copy-of select=".[@mode='replace'][ancestor-or-self::tei:local][1]"/></xsl:when>
                        <xsl:otherwise><xsl:copy-of select="."/></xsl:otherwise>
                    </xsl:choose>
            </xsl:for-each-group>    
        </availableAtts>
    </xsl:function>

    <xsl:template match="/">
        <!-- Create the index page for the current form, creates sub-form navigation-->
        <xsl:variable name="mainFormName" select="$configDoc//formName"/>
        <xsl:result-document href="../{concat($mainFormName,'/index.xhtml')}" format="xform">
            <xsl:call-template name="formMainPage"/>
        </xsl:result-document>
        <!-- Output an XForm for each subform listed in the config.xml subforms section -->
        <xsl:for-each select="$configDoc//subforms/subform">
            <xsl:variable name="subform" select="."/>
            <xsl:variable name="formName" select="@formName"/>
            <!-- Ouput XForms xml instance with finalized schema rules -->
            <xsl:result-document href="../{$mainFormName}/templates/{$formName}-schemaConstraints.xml" format="tei">
                <xsl:call-template name="generateSchemaInstance">
                    <xsl:with-param name="subform" select="."/>
                </xsl:call-template>
            </xsl:result-document>
            <xsl:result-document href="../{concat($mainFormName,'/',$formName)}.xhtml" format="xform">
                <xsl:call-template name="xform">
                    <xsl:with-param name="subform" select="."/>
                </xsl:call-template>
            </xsl:result-document>
            <xsl:for-each select="subform">
                <xsl:variable name="subFormName" select="@formName"/>
                <xsl:result-document href="../{concat($mainFormName,'/',$formName,'/',$subFormName)}.xhtml" format="xform">
                    <xsl:call-template name="xform">
                        <xsl:with-param name="subform" select="."/>
                    </xsl:call-template>
                </xsl:result-document>
            </xsl:for-each>
        </xsl:for-each>   
        <!-- Output any controlled vocab subforms -->
        <xsl:for-each-group select="$configDoc//lookup" group-by="@formName">
            <xsl:result-document href="../{concat($mainFormName,'/lookup/',@formName)}.xhtml" format="xform">
                <xsl:call-template name="controlledVocabLookup">
                    <xsl:with-param name="lookup" select="."/>
                </xsl:call-template>
            </xsl:result-document>                    
        </xsl:for-each-group>
        
        <!-- Output an XForm with all possible elements, used to add new elements -->
        <xsl:result-document href="../{$mainFormName}/templates/elementTemplate.xml" format="tei">
            <xsl:call-template name="elementTemplate"/>
        </xsl:result-document>
        
        <!-- Output an XForm with all possible attributes, used to add new attributes -->
        <xsl:result-document href="../{$mainFormName}/templates/attributesTemplate.xml" format="tei">
            <xsl:call-template name="attributesTemplate"/>
        </xsl:result-document>
        <!-- Output an XForm with all possible attributes, used to add new attributes -->
        <xsl:result-document href="../{$mainFormName}/templates/availableAttributes.xml" format="tei">
            <xsl:call-template name="availableAttributes"/>
        </xsl:result-document>
    </xsl:template>
    
    <!-- Template for forms index page -->
    <xsl:template name="formMainPage">
        <xsl:variable name="mainFormName" select="$configDoc//formName"/>
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html xmlns="http://www.w3.org/1999/xhtml" 
            xmlns:xi="http://www.w3.org/2001/XInclude"
            xmlns:ev="http://www.w3.org/2001/xml-events" 
            xmlns:tei="http://www.tei-c.org/ns/1.0"
            xmlns:xf="http://www.w3.org/2002/xforms"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
                <meta name="author" content="{$configDoc//formAuthor}"/>
                <meta name="description" content="{$configDoc//formDesc}"/>
                <title>
                    <xsl:value-of select="$configDoc//formTitle"/>
                </title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.8.1/font/bootstrap-icons.css"/>
                <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/style.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <script type="text/javascript">
                    
                </script>
                <!-- XForms Model -->
                <xf:model id="m-mss">
                    <xf:instance id="i-rec">
                        <data></data>
                    </xf:instance>
                    <xf:instance id="i-admin">
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <editor role="creator"></editor>
                            <idno type="URI"></idno>
                        </TEI>
                    </xf:instance>
                    <xf:instance id="i-elementTemplate" src="forms/{$mainFormName}/templates/elementTemplate.xml"/>
                    <xf:instance id="i-attributeTemplate" src="forms/{$mainFormName}/templates/attributesTemplate.xml"/>
                    <xf:instance id="i-availableElements" src="forms/{$mainFormName}/templates/elementTemplate.xml"/>
                    <xf:instance id="i-upload">
                        <xml-base64 xsi:type="xs:base64Binary"/>
                    </xf:instance>
                    <xf:instance id="i-search">
                        <data><q></q></data>
                    </xf:instance>
                    <xf:instance id="i-search-results">
                        <data></data>
                    </xf:instance>
                    <xf:instance id="i-selected-search">
                        <data>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-selected">
                        <data>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-selectTemplate">
                        <data>
                            <xsl:for-each select="$configDoc//template">
                                <template name="{@name}" src="{@src}"></template>
                            </xsl:for-each>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-subforms">
                        <data>
                            <xsl:for-each select="$configDoc//subforms/subform">
                                <subform formName="{@formName}" selected="false"></subform>
                            </xsl:for-each>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-submission">
                        <response status="success">
                            <message>Submission result</message>
                        </response>
                    </xf:instance>
                    <!-- i-insert-elements -->
                    <xf:instance id="i-insert-elements">
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <element/>
                        </TEI>
                    </xf:instance>
                    <xf:instance id="i-insert-attributes">
                        <TEI xmlns="http://www.tei-c.org/ns/1.0">
                            <attribute/>
                        </TEI>
                    </xf:instance>
                    <xf:instance id="i-submission">
                        <response status="success">
                            <message>Submission result</message>
                        </response>
                    </xf:instance>
                    <xf:instance id="i-submission-params">
                        <xsl:copy-of select="$configDoc//recordManagement"/>
                    </xf:instance>
                    <!-- Keep track of element positions when moving them up or down -->
                    <xf:instance id="i-move">
                        <data xmlns="">
                            <tmp/>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-repeatIndex">
                        <data xmlns="">
                            <index>1</index>
                        </data>
                    </xf:instance>
                    <!-- Pretty print -->
                    <xf:instance id="i-prettyPrint" src="forms/formGenerator/prettyPrint.xsl">
                    </xf:instance>
                    <xf:submission id="s-load-template" 
                        method="post" ref="instance('i-selected')" 
                        replace="instance" 
                        instance="i-rec" 
                        serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/get-rec.xql?template=true&amp;path=',instance('i-selected'))"/>
                        <xf:message level="modeless" ev:event="xforms-submit-done"> Data Loaded! </xf:message>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    
                    <xf:submission id="s-load-template-search" 
                        method="post" ref="instance('i-selected-search')" 
                        replace="instance" 
                        instance="i-rec" 
                        serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/get-rec.xql?template=true&amp;path=',instance('i-selected-search'))"/>
                        <xf:message level="modeless" ev:event="xforms-submit-done"> Data Loaded! </xf:message>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    
                    <xf:submission id="s-search-saved" 
                        method="post" 
                        ref="instance('i-search')" 
                        replace="instance" 
                        instance="i-search-results" 
                        serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/get-rec.xql?search=true&amp;q=',instance('i-search'),'&amp;eXistCollection=',string(instance('i-submission-params')//*:retrieveOptions/*:option[@name='exist-db']/*:parameter[@name='eXistCollection']))"/>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    
                    <xf:submission id="s-browse-saved" 
                        method="post" ref="instance('i-search')" 
                        replace="instance" 
                        instance="i-search-results" 
                        serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/get-rec.xql?search=true&amp;view=all&amp;eXistCollection=',string(instance('i-submission-params')//*:retrieveOptions/*:option[@name='exist-db']/*:parameter[@name='eXistCollection']))"/>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    <xf:submission id="s-post-to-update" 
                        action="services/upload.xql" 
                        ref="instance('i-upload')"  
                        replace="instance" 
                        instance="i-rec" 
                        method="post">
                        <xf:message level="modeless" ev:event="xforms-submit-done"> Data Loaded! </xf:message>
                        <xf:message level="modeless" ev:event="xforms-submit-error"> Submit error. </xf:message>
                    </xf:submission>
                    <!-- Save records -->
                    <!-- Download XML to your desktop -->
                    <xf:submission id="s-download-xml" ref="instance('i-rec')" show="new" method="post" replace="all" action="form.xq?form=services/download.xml?type=download"/>
                    <!-- Download View XML in browser -->
                    <xf:submission id="s-view-xml" ref="instance('i-rec')" show="new" method="post" replace="all" action="services/submit.xql?type=view"/>
                    
                    <!-- Save record to Database  -->
                    <xf:submission id="s-save" 
                        ref="instance('i-rec')"
                        replace="instance" 
                        instance="i-submission"  
                        method="post">
                        <xf:resource value="concat('services/submit.xql?type=save&amp;eXistCollection=',string(instance('i-submission-params')//*:saveOptions/*:option[@name='exist-db']/*:parameter[@name='eXistCollection']))"/>
                        <xf:action ev:event="xforms-submit-done">
                            <xf:message ref="instance('i-submission')//*:message"/>
                        </xf:action>
                        <xf:action ev:event="xforms-submit-error">
                            <xf:message ref="instance('i-submission')//*:message"/>
                        </xf:action>
                    </xf:submission>
                    
                    <!-- Save record to github -->
                    <xf:submission id="s-github" 
                        ref="instance('i-rec')" 
                        replace="instance" 
                        instance="i-submission"
                        method="post">
                        <xf:resource value="concat('services/submit.xql?type=github&amp;githubRepoName=',string(instance('i-submission-params')//*:parameter[@name='githubRepoName']),'&amp;githubPath=',string(instance('i-submission-params')//*:parameter[@name='githubPath']),'&amp;githubOwner=',string(instance('i-submission-params')//*:parameter[@name='githubOwner']),'&amp;githubBranch=',string(instance('i-submission-params')//*:parameter[@name='githubBranch']))"/>
                       <xf:action ev:event="xforms-submit-done">
                            <xf:message ref="instance('i-submission')//*:message"/>
                        </xf:action>
                        <xf:action ev:event="xforms-submit-error">
                            <xf:message ev:event="xforms-submit-error" level="modal">Unable to submit your additions at this time, you may download your changes and email them to us.</xf:message>
                        </xf:action>
                    </xf:submission>
                </xf:model>       
            </head>
            <body>
                <xsl:call-template name="navbar"/>
                <div class="container-fluid">
                    <div class="row">
                        <nav id="sidebarMenu" class="col-md-3 col-lg-2 d-md-block bg-light sidebar collapse">
                            <div class="position-sticky pt-3">
                                <ul class="nav flex-column">
                                    <li class="nav-item">
                                        <xf:trigger appearance="minimal" class="nav-link">
                                            <xf:label><span data-feather="home"></span> Main Page &#160;</xf:label>
                                            <xf:action ev:event="DOMActivate">
                                                <xf:toggle case="view-main-entry"/>
                                            </xf:action>
                                        </xf:trigger>
                                    </li>
                                    <li class="nav-item">
                                        <xf:trigger appearance="minimal" class="nav-link">
                                            <xf:label><span data-feather="home"></span> Admin Page &#160;</xf:label>
                                            <xf:action ev:event="DOMActivate">
                                                <xf:toggle case="view-admin"/>
                                            </xf:action>
                                        </xf:trigger>
                                    </li>
                                    <xsl:for-each select="$configDoc//subforms/subform">
                                        <xsl:variable name="subformPath" select="@xpath"/>
                                        <xsl:variable name="elementName" select="substring-after(tokenize(@xpath,'/')[last()],':')"/>
                                        <xsl:variable name="path" select="replace(replace(replace(replace(replace($subformPath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//'),'tei:','*:')"/>
                                        <xsl:variable name="repeatIndexId" select="concat('navRepeat',@formName)"/>
                                        <li class="nav-item">
                                            <xf:trigger appearance="minimal" ref="instance('i-subforms')//*:subform[@formName = '{string(@formName)}']" class="nav-link">
                                                <xf:label><xsl:value-of select="string(@formLabel)"/> &#160;</xf:label>
                                                <xf:action ev:event="DOMActivate">
                                                    <xf:toggle case="view-data-entry"/>
                                                    <xf:unload targetid="subform"/>
                                                    <xf:setvalue ref="instance('i-subforms')//*:subform[@selected = 'true']/@selected" value="'false'"/>
                                                    <xf:load if="@selected != 'true'" show="embed" targetid="subform" resource="{concat('form.xq?form=forms/',$mainFormName,'/',@formName,'.xhtml')}"/>
                                                    <xf:setvalue ref="@selected" value="'true'"/>
                                                    <xsl:element name="setvalue" namespace="http://www.w3.org/2002/xforms">
                                                        <xsl:attribute name="ref">instance('i-repeatIndex')/index</xsl:attribute>
                                                        <xsl:attribute name="value">1</xsl:attribute>
                                                    </xsl:element>
                                                </xf:action>
                                            </xf:trigger>
                                        </li>
                                        <xf:repeat ref="instance('i-rec'){$path}[position() &gt; 1]" id="{$repeatIndexId}">
                                            <li class="nav-item">
                                                <xf:trigger appearance="minimal" class="nav-link">
                                                    <xf:label><xsl:value-of select="string(@formLabel)"/> &#160;[<xf:output value="position() + 1"/>]</xf:label>
                                                    <xf:action ev:event="DOMActivate">
                                                        <xf:toggle case="view-data-entry"/>
                                                        <xf:unload targetid="subform"/>
                                                        <xf:setvalue ref="instance('i-subforms')//*:subform[@selected = 'true']/@selected" value="'false'"/>
                                                        <xf:load if="@selected != 'true'" show="embed" targetid="subform" resource="{concat('form.xq?form=forms/',$mainFormName,'/',@formName,'.xhtml')}"/>
                                                        <xf:setvalue ref="@selected" value="'true'"/>
                                                        <xsl:element name="setvalue" namespace="http://www.w3.org/2002/xforms">
                                                            <xsl:attribute name="ref">instance('i-repeatIndex')/index</xsl:attribute>
                                                            <xsl:attribute name="value">index('<xsl:value-of select="$repeatIndexId"/>') + 1</xsl:attribute>
                                                        </xsl:element>
                                                    </xf:action>
                                                </xf:trigger>                                                     
                                            </li>
                                        </xf:repeat>
                                    </xsl:for-each>
                                </ul>
                            </div>
                        </nav>
                        <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                            <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 border-bottom">
                                <h1 class="h2"><xsl:value-of select="$configDoc//formTitle"/></h1>
                                <div class="btn-toolbar mb-2 mb-md-0">
                                    <div class="btn-group me-2">
                                        <div class="submission float-end">
                                            <xsl:if test="$configDoc//saveOptions/option[@name='github'][@enable='true']">
                                                <xf:submit class="btn btn-outline-secondary btn-sm" submission="s-github" appearance="minimal">
                                                    <xf:label> Submit to GitHub </xf:label>
                                                </xf:submit>
                                            </xsl:if>
                                            <xsl:if test="$configDoc//saveOptions/option[@name='exist-db'][@enable='true']">
                                                <xf:submit class="btn btn-outline-secondary btn-sm" submission="s-save" appearance="minimal">
                                                    <xf:label> Save to Database </xf:label>
                                                </xf:submit>
                                            </xsl:if>
                                            <xf:submit class="btn btn-outline-secondary btn-sm" submission="s-download-xml" appearance="minimal">
                                                <xf:label> Download XML </xf:label>
                                            </xf:submit>
                                            <xf:submit class="btn btn-outline-secondary btn-sm" submission="s-view-xml" appearance="minimal">
                                                <xf:label> View XML </xf:label>
                                            </xf:submit>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <!-- Form description -->
                            <xsl:if test="$configDoc//formDesc != ''">
                                <p class="alert alert-light hint"><xsl:value-of select="$configDoc//formDesc"/></p>
                            </xsl:if>
                            <xf:switch id="edit" class="mainContent panel">
                                <xf:case id="view-main-entry" selected="true()">
                                    <!-- Load an existing template -->
                                    <div class="fileLoading">
                                        <h4 class="h6">New <small class="text-muted">(from template)</small></h4>
                                        <div class="input-group mb-3">
                                            <xf:select1 class="form-control" xmlns="http://www.w3.org/2002/xforms" ref="instance('i-selected')">
                                                 <xf:label></xf:label>
                                                 <xf:itemset ref="instance('i-selectTemplate')//*:template">
                                                     <xf:label ref="@name"/>
                                                     <xf:value ref="@src"/>
                                                 </xf:itemset>
                                             </xf:select1>
                                            <xf:submit class="btn btn-outline-secondary" submission="s-load-template" appearance="minimal">
                                                <xf:label> Load template </xf:label>    
                                            </xf:submit>
                                        </div>
                                    </div>
                                    <div class="fileLoading">
                                        <h4 class="h6">Search <small class="text-muted">(database)</small></h4>
                                        <div class="input-group mb-3">
                                            <xf:input class="form-control" ref="instance('i-search')" incremental="true">
                                                <xf:label></xf:label>
                                            </xf:input>
                                            <xf:submit class="btn btn-outline-secondary" submission="s-search-saved" appearance="minimal">
                                                <xf:label> Search </xf:label>
                                            </xf:submit>
                                            <xf:submit class="btn btn-outline-secondary" submission="s-browse-saved" appearance="minimal">
                                                <xf:label> Browse </xf:label>
                                            </xf:submit>
                                        </div>
                                        <div class="input-group mb-3">
                                            <xf:select1  appearance="full" class="checkbox select-group form-control" xmlns="http://www.w3.org/2002/xforms" ref="instance('i-selected-search')">
                                                <xf:label></xf:label>
                                                <xf:itemset ref="instance('i-search-results')//*:record">
                                                    <xf:label ref="@name"/>
                                                    <xf:value ref="@src"/>
                                                </xf:itemset>
                                            </xf:select1>
                                            <xf:submit class="btn btn-outline-secondary" submission="s-load-template-search" appearance="minimal">
                                                <xf:label> Load selected record </xf:label>
                                            </xf:submit>
                                        </div>
                                    </div>
                                    <div class="fileLoading">
                                        <h4 class="h6">Upload <small class="text-muted">(from file system)</small></h4>
                                        <div class="input-group mb-3">
                                            <xf:upload class="form-control" ref="instance('i-upload')" appearance="minimal">
                                                <xf:label></xf:label>
                                            </xf:upload>
                                            <!-- WS:Note add upload graphic, make inline with above? -->
                                            <xf:submit submission="s-post-to-update" class="btn btn-outline-secondary" appearance="minimal">
                                                <xf:label>Load</xf:label>
                                            </xf:submit>
                                        </div>
                                    </div>                                    
                                    <div class="card preview">
                                        <div class="card-header">Preview XML</div>
                                        <xf:group>
                                            <!--
                                            <xf:output value="serialize(instance('i-rec'))"/>
                                            -->
                                            <xf:setvalue ref="instance('i-rec')" ev:event="DOMActivate" value="transform(instance('i-rec'),serialize(instance('i-prettyPrint')),true())"/>
                                        </xf:group>
                                    </div>
                                </xf:case>
                                <xf:case id="view-admin">
                                    <xf:repeat ref="instance('i-rec')//*:titleStmt/*:editor[@role='creator']">
                                        <div class="input-group mb-3">
                                            <xf:input ref="." class="form-control">
                                                <xf:label>Creator: </xf:label>
                                                <xf:alert>Add your name</xf:alert>
                                            </xf:input>
                                            <xf:trigger xmlns="http://www.w3.org/2002/xforms" appearance="minimal" class="btn controls remove inline">
                                                <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-x-circle"/></xf:label>
                                                <xf:delete ev:event="DOMActivate" ref="."/>
                                            </xf:trigger>
                                        </div>
                                    </xf:repeat>
                                    <xf:trigger class="btn btn-outline-secondary btn-sm controls add" appearance="full">
                                        <xf:label><i class="bi bi-plus-circle"/> Add Creator
                                        </xf:label>
                                        <xf:insert ev:event="DOMActivate" ref="instance('i-rec')//*:titleStmt/child::*" at="last()" origin="instance('i-admin')//*:editor" position="after"/>
                                    </xf:trigger><br/>
                                    <div class="input-group mb-3">
                                        <xf:input ref="instance('i-rec')//*:publicationStmt[1]/*:idno[@type='URI']" class="form-control">
                                            <xf:label>URI: </xf:label>
                                            <xf:alert>* Use the following URI pattern: https://majlis.net/COLLECTION/UNIQUE_ID/tei</xf:alert>
                                        </xf:input>
                                    </div>
                                </xf:case>
                                <xf:case id="view-data-entry">    
                                    <xf:group ref="instance('i-rec')">
                                        <xf:group id="subform"/>                                        
                                    </xf:group>
                                </xf:case>
                            </xf:switch>
                        </main>
                    </div>
                </div>
            </body>
        </html>
    </xsl:template>
    
    <!-- XForm for each subform listed in the config file -->
    <xsl:template name="xform">
        <xsl:param name="subform"/>
        <xsl:variable name="mainFormName" select="$configDoc//formName"/>
        <xsl:variable name="subformName" select="$subform/@formName"/>
        <xsl:variable name="template" select="document($subform/xmlTemplate/@src)"/>
        <xsl:variable name="repeatIndex">
            <xsl:choose>
                <xsl:when test="$subform/parent::*:subforms">i-repeatIndex</xsl:when>
                <xsl:when test="$subform/parent::*:subform">i-<xsl:value-of select="string($subformName)"/>-repeatIndex</xsl:when>
                <xsl:otherwise>i-repeatIndex</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xpath" select="string($subform/@xpath)"/>
        <xsl:variable name="path" select="replace(replace(replace(replace(replace($xpath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//'),'tei:','*:')"/>
        <!-- 
        <xsl:variable name="subsequence">
            <xsl:evaluate xpath="$xpath" context-item="$template"/>
        </xsl:variable>
        -->
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude"
            xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:tei="http://www.tei-c.org/ns/1.0"
            xmlns:xf="http://www.w3.org/2002/xforms">
            <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
                <meta name="author" content="{$configDoc//formAuthor}"/>
                <meta name="description" content="{$configDoc//formDesc}"/>
                <title><xsl:value-of select="$configDoc//formTitle"/></title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.8.1/font/bootstrap-icons.css"/>
                <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/style.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <xf:model id="m-mss">
                    <xf:instance id="i-schemaConstraints" src="forms/{$mainFormName}/templates/{$subformName}-schemaConstraints.xml"/>
                    <xf:instance id="i-{string($subformName)}-schemaConstraints" src="forms/{$mainFormName}/templates/{$subformName}-schemaConstraints.xml"/>
                    <xf:instance id="i-{string($subformName)}-subforms">
                        <data xmlns="">
                            <xsl:for-each select="$subform/subform">
                                <subform formName="{@formName}" selected="false"></subform>
                            </xsl:for-each>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-{string($subformName)}-repeatIndex">
                        <data xmlns="">
                            <index>1</index>
                        </data>
                    </xf:instance>
                </xf:model>
            </head>
            <body>
                <!-- Path to root element for the current subform -->
                <xsl:variable name="elementPath" select="replace(replace(replace(replace($xpath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//')"/>
                <!-- Current element name -->
                <xsl:variable name="elementName" select="substring-after(tokenize($xpath,'/')[last()],':')"/>
                <xsl:variable name="parentXPath" select="substring-before($path,concat('*:',$elementName))"/>
                <!-- Number of children, maximum repeats, prevents endless looping in creating the form.  -->
                <xsl:variable name="maxLevel">
                    <xsl:variable name="schemaInstanceDoc">
                        <xsl:call-template name="generateSchemaInstance">
                            <xsl:with-param name="subform" select="$subform"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:variable name="levels">
                        <xsl:for-each select="$schemaInstanceDoc//@currentLevel">
                            <xsl:sort select="xs:integer(.)" order="descending"/>
                            <xsl:if test="position() = 1">
                                <xsl:copy-of select="string(.)"/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:choose>
                        <xsl:when test="$levels castable as xs:integer"><xsl:value-of select="xs:integer($levels)"/></xsl:when>
                        <xsl:otherwise>1</xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <!-- WS:Note need to move up and down, also if parent element does not exist will be a problem -->
                <h2 class="h3 mainElement">
                    <xf:trigger appearance="minimal" class="btn controls remove inline" 
                        xmlns="http://www.w3.org/2002/xforms">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-x-circle"/></xf:label>
                        <xf:delete ev:event="DOMActivate" ref="{$path}[position() = instance('{$repeatIndex}')/index]"/>
                    </xf:trigger>
                    <xf:trigger class="btn controls add" appearance="minimal">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-plus-circle"></i></xf:label>
                        <xf:insert ev:event="DOMActivate" 
                            context="{$parentXPath}" 
                            origin="instance('i-elementTemplate')//*[local-name() = '{$elementName}']" 
                            position="after"></xf:insert>
                    </xf:trigger> 
                    <xsl:value-of select="$subform/@formLabel"/>
                    <xsl:if test="$subform/subform"> [<xf:output value="instance('i-repeatIndex')/index"/>]</xsl:if>
                </h2>
                <xsl:if test="$subform/formDesc">
                    <p class="alert alert-light hint"><xsl:value-of select="$subform/formDesc"/></p>    
                </xsl:if> 
                <xf:group namespace="http://www.w3.org/2002/xforms" ref="{$path}[position() = instance('{$repeatIndex}')/index]" id="{$elementName}-root">
                    <xsl:choose>
                        <xsl:when test="$subform/subform">
                            <div class="container-fluid">
                                <div class="row">
                                    <nav id="sidebarMenu" class="submenu col-md-3 col-lg-2 d-md-block sidebar collapse">
                                        <div class="position-sticky pt-3">
                                            <ul class="nav flex-column">
                                                <xsl:for-each select="subform">
                                                    <xsl:variable name="subformPath" select="@xpath"/>
                                                    <xsl:variable name="path" select="replace(replace(replace(replace(replace($subformPath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//'),'tei:','*:')"/>
                                                    <xsl:variable name="repeatIndexId" select="concat($subformName,'NavRepeat',@formName)"/>
                                                    <li class="nav-item">
                                                        <xf:trigger appearance="minimal" class="nav-link">
                                                            <xsl:attribute name="ref">instance('<xsl:value-of select="concat('i-',$subformName,'-subforms')"/>')//*:subform[@formName = '<xsl:value-of select="string(@formName)"/>']</xsl:attribute>
                                                            <xf:label><xsl:value-of select="string(@formLabel)"/> &#160;</xf:label>
                                                            <xf:action ev:event="DOMActivate">
                                                                <xf:toggle case="{$subformName}SubformDataEntry"/>
                                                                <xf:unload targetid="{$subformName}Subform"/>
                                                                <xf:setvalue value="'false'">
                                                                    <xsl:attribute name="ref">instance('<xsl:value-of select="concat('i-',$subformName,'-subforms')"/>')//*:subform[@selected = 'true']/@selected</xsl:attribute>
                                                                </xf:setvalue> 
                                                                <xf:load if="@selected != 'true'" show="embed" targetid="{$subformName}Subform" resource="{concat('form.xq?form=forms/',$mainFormName,'/',$subformName,'/',@formName,'.xhtml')}"/>
                                                                <xf:setvalue ref="@selected" value="'true'"/>
                                                                <xsl:element name="setvalue" namespace="http://www.w3.org/2002/xforms">
                                                                    <xsl:attribute name="ref">instance('<xsl:value-of select="concat('i-',$subformName,'-repeatIndex')"/>')/index</xsl:attribute>
                                                                    <xsl:attribute name="value">1</xsl:attribute>
                                                                </xsl:element>
                                                            </xf:action>
                                                        </xf:trigger>
                                                    </li>
                                                </xsl:for-each>
                                            </ul>
                                        </div>
                                    </nav>
                                    <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                                        <xf:switch id="{$subformName}LoadSubforms" class="mainContent panel">
                                            <xf:case id="{$subformName}SubformMain" selected="true()">
                                                <h4>Select section to edit</h4>
                                            </xf:case>
                                            <xf:case id="{$subformName}SubformDataEntry"> 
                                                <xf:group id="{$subformName}Subform"/>                                        
                                            </xf:case>
                                        </xf:switch>
                                    </main>
                                </div>
                            </div>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:call-template name="xformElementUI">
                                <xsl:with-param name="subform" select="$subform"/>
                                <xsl:with-param name="xpath" select="$elementPath"/>
                                <xsl:with-param name="xpathIndex"><xsl:value-of select="$elementPath"/>[position() = instance('i-repeatIndex')/index]</xsl:with-param>
                                <xsl:with-param name="currentLevel">1</xsl:with-param>
                                <xsl:with-param name="maxLevel" select="$maxLevel"/>
                                <xsl:with-param name="repeatID"/>
                            </xsl:call-template>
                        </xsl:otherwise>
                    </xsl:choose>  
                </xf:group>  
             </body>
        </html>
    </xsl:template>
     
    <!-- Controlled vocabulary popup as subform -->
    <xsl:template name="controlledVocabLookup">
        <xsl:param name="lookup"/>
        <xsl:variable name="mainFormName" select="$configDoc//formName"/>
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:xi="http://www.w3.org/2001/XInclude"
            xmlns:ev="http://www.w3.org/2001/xml-events" xmlns:tei="http://www.tei-c.org/ns/1.0"
            xmlns:xf="http://www.w3.org/2002/xforms">
            <head>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no"/>
                <meta name="author" content="{$configDoc//formAuthor}"/>
                <meta name="description" content="{$configDoc//formDesc}"/>
                <title>Controlled Vocabulary Form for <xsl:value-of select="$configDoc//formTitle"/></title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.8.1/font/bootstrap-icons.css"/>
                <link rel="stylesheet" type="text/css" href="resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/style.css"/>
                <link rel="stylesheet" type="text/css" href="resources/css/xforms.css"/>
                <script type="text/javascript" src="resources/js/jquery.min.js"/>
                <script type="text/javascript" src="resources/bootstrap/js/bootstrap.min.js"/>
                <xf:model id="m-lookup">
                    <xf:instance id="i-rec">
                        <data/>
                    </xf:instance>
                    <xf:instance id="i-lookup-query">
                        <data xmlns="">
                            <q/>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-lookup-results">
                        <data xmlns=""/>
                    </xf:instance>
                    <xf:instance id="i-lookup-selected">
                        <data xmlns="">
                            <selected/>
                        </data>
                    </xf:instance>
                    <xf:instance id="i-lookup-add">
                        <data xmlns="">
                        </data>
                    </xf:instance>
                    <!--
                    <xf:submission id="s-lookup" method="get" replace="instance" instance="i-lookup-results" serialization="none" mode="synchronous">
                        <xf:resource value="concat('services/getControlledVocab.xql?apiURL=','{string($lookup/@api)}', instance('i-lookup-query')//q),"/>
                    </xf:submission>
                    -->
                    <xf:submission id="s-lookup" method="get" replace="instance" instance="i-lookup-results" serialization="none" mode="synchronous">
                        <xf:resource value="concat('{string($lookup/@api)}', instance('i-lookup-query')//q),"/>
                    </xf:submission>
                </xf:model>
            </head>
            <body>
                <div class="d-flex flex-column justify-content-center align-items-center">
                    <h2 class="h3 mainElement"><xsl:value-of select="$lookup/@lookupLabel"/></h2>
                    <p>Search controlled vocabulary  <xf:output value="local-name(current())"></xf:output></p>
                    <div class="input-group">    
                        <xf:input id="search-q" ref="instance('i-lookup-query')/q" incremental="true">
                            <xf:label/>
                            <xf:toggle ev:event="DOMFocusIn" case="show-autocompletion"/>    
                        </xf:input>
                        <xf:submit class="btn btn-outline-secondary btn-sm" submission="s-lookup" appearance="minimal">
                            <xf:label> <i class="bi bi-search"/> </xf:label>    
                        </xf:submit>
                    </div>
                        <xf:select1 ref="instance('i-lookup-selected')/child::*" appearance="full" class="checkbox select-group">
                            <xf:itemset ref="instance('i-lookup-results')//*:title/child::*[1]">
                                <xf:label ref="."/>
                                <xf:value ref="."/>
                            </xf:itemset>
                            <xf:action ev:event="xforms-value-changed">
                                <xf:insert ev:event="DOMActivate" 
                                    ref="instance('i-lookup-add')/child::*" 
                                    origin="instance('i-lookup-results')//*:title/child::*[1][. = instance('i-lookup-selected')//selected]"/>
                            </xf:action>
                        </xf:select1>
                        <xf:trigger class="btn btn-outline-secondary btn-sm" appearance="full" ref=".">
                            <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-plus-circle"></i> Add to Record</xf:label>
                            <xf:insert ev:event="DOMActivate" ref="." at="." origin="instance('i-lookup-selected')/selected/child::*" position="after"/>
                            <xf:delete ev:event="DOMActivate" ref="."/>
                            <xf:setvalue ref="instance('i-lookup-query')/q" value="''"/>
                            <xf:delete ref="instance('i-lookup-results')//child::*"/>
                            <xf:delete ref="instance('i-lookup-selected')//child::*"/>
<!--                            <message level="modal" ev:event="DOMActivate">Added</message>-->
                            <xf:message level="modeless" ev:event="DOMActivate"> Added </xf:message>
                        </xf:trigger>
                </div>
            </body>
        </html>
    </xsl:template>
    
     <!-- Build repeating XForms element -->
    <xsl:template name="xformElementUI">
        <xsl:param name="subform"/>
        <xsl:param name="xpath"/>
        <xsl:param name="xpathIndex"/>
        <xsl:param name="currentLevel"/>
        <xsl:param name="maxLevel"/>
        <xsl:param name="repeatID"/>
        <xsl:variable name="subformName" select="string($subform/@formName)"/>
        <xsl:variable name="elementPath" select="replace(replace(replace(replace($subform/@xpath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//')"/>
        <xsl:variable name="xpathIndex">
            <xsl:choose>
                <xsl:when test="$subform/parent::*:subform and $currentLevel = 1">
                    <xsl:variable name="parentXPath" select="string($subform/parent::*:subform/@xpath)"/>
                    <xsl:variable name="parentXPathCleaned" select="replace(replace(replace(replace(replace($parentXPath, 'Q\{http://www.tei-c.org/ns/1.0\}', '*:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//'),'tei:','*:')"/>
                    <xsl:value-of select="$parentXPathCleaned"/><xsl:text>[position() = instance('i-repeatIndex')/index]/</xsl:text><xsl:value-of select="replace($elementPath,'tei:','*:')"/><xsl:text>[position() = instance('i-</xsl:text><xsl:value-of select="string($subformName)"/><xsl:text>-repeatIndex')/index]/*</xsl:text>
                </xsl:when>
                <xsl:otherwise><xsl:value-of select="$xpathIndex"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="schemaInstanceDoc">
            <xsl:call-template name="generateSchemaInstance">
                <xsl:with-param name="subform" select="$subform"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:variable name="maxLevel">
            <xsl:choose>
                <xsl:when test="$subform/parent::*:subform">
                    <xsl:variable name="schemaInstanceDoc">
                        <xsl:call-template name="generateSchemaInstance">
                            <xsl:with-param name="subform" select="$subform"/>
                        </xsl:call-template>
                    </xsl:variable>
                    <xsl:variable name="levels">
                        <xsl:for-each select="$schemaInstanceDoc//@currentLevel">
                            <xsl:sort select="xs:integer(.)" order="descending"/>
                            <xsl:if test="position() = 1">
                                <xsl:copy-of select="string(.)"/>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:variable>
                    <xsl:choose>
                        <xsl:when test="$levels castable as xs:integer"><xsl:value-of select="xs:integer($levels)"/></xsl:when>
                        <xsl:otherwise>1</xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise><xsl:value-of select="$maxLevel"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- Build XForm element -->
        <div class="btn-toolbar justify-content-between mt-3 elementControls" role="toolbar">
            <div class="btn-group" role="group">
                <xf:trigger appearance="minimal" class="btn controls remove inline" xmlns="http://www.w3.org/2002/xforms">
                    <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-x-circle"/></xf:label>
                    <xf:delete ev:event="DOMActivate" ref="."/>
                </xf:trigger>
                <xsl:if test="$currentLevel &gt; 1">
                    <xf:trigger appearance="minimal" class="btn controls moveUp inline" xmlns="http://www.w3.org/2002/xforms">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-arrow-up-circle"></i></xf:label>
                        <xf:action ev:event="DOMActivate">
                            <!-- Store index of current item -->
                            <xsl:element name="setvalue" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="ref">instance('i-move')/tmp</xsl:attribute>
                                <xsl:attribute name="value">index('<xsl:value-of select="$repeatID"/>')</xsl:attribute>
                            </xsl:element>
                            <!-- Insert/copy current node -->
                            <xsl:element name="insert" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="origin">instance('i-rec')<xsl:value-of select="$xpathIndex"/>[index('<xsl:value-of select="$repeatID"/>')]</xsl:attribute>
                                <xsl:attribute name="nodeset">instance('i-rec')<xsl:value-of select="$xpathIndex"/></xsl:attribute>
                                <xsl:attribute name="at">index('<xsl:value-of select="$repeatID"/>') - 1</xsl:attribute>
                                <xsl:attribute name="position">before</xsl:attribute>
                            </xsl:element>
                            <!-- Delete original node -->
                            <xsl:element name="delete" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="nodeset">instance('i-rec')<xsl:value-of select="$xpathIndex"/>[instance('i-move')/tmp + 1]</xsl:attribute>
                            </xsl:element>
                        </xf:action>
                    </xf:trigger>
                    <xf:trigger appearance="minimal" class="btn controls moveDown inline" xmlns="http://www.w3.org/2002/xforms">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-arrow-down-circle"></i></xf:label>
                        <xf:action ev:event="DOMActivate">
                            <!-- Store index of current item -->
                            <xsl:element name="setvalue" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="ref">instance('i-move')/tmp</xsl:attribute>
                                <xsl:attribute name="value">index('<xsl:value-of select="$repeatID"/>')</xsl:attribute>
                            </xsl:element>
                            <!-- Insert/copy current node -->
                            <xsl:element name="insert" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="origin">instance('i-rec')<xsl:value-of select="$xpathIndex"/>[index('<xsl:value-of select="$repeatID"/>')]</xsl:attribute>
                                <xsl:attribute name="nodeset">instance('i-rec')<xsl:value-of select="$xpathIndex"/></xsl:attribute>
                                <xsl:attribute name="at">index('<xsl:value-of select="$repeatID"/>') + 1</xsl:attribute>
                                <xsl:attribute name="position">after</xsl:attribute>
                            </xsl:element>
                            <!-- Delete original node -->
                            <xsl:element name="delete" namespace="http://www.w3.org/2002/xforms">
                                <xsl:attribute name="nodeset">.</xsl:attribute>
                            </xsl:element>
                        </xf:action>
                    </xf:trigger>
                </xsl:if>
                <span class="elementLabel">
                    <xf:output value="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/@elementLabel" class="elementLabel"/>
                    <i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-question-circle triggerElementTooltip"/>
                    <xf:output ref="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:desc/text()" class="elementTooltip"/>
                </span>
                <div class="input-group float-end">
                    <xf:select1 xmlns="http://www.w3.org/2002/xforms" ref="instance('i-availableElements')/*[local-name() = local-name(current())][instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:availableAtts/descendant-or-self::*:attDef]">
                        <xf:label></xf:label>
                        <xf:itemset ref="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:availableAtts/descendant-or-self::*:attDef">
                            <xf:label ref="@ident"/>
                            <xf:value ref="@ident"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">
                            <xf:setvalue ref="instance('i-insert-attributes')//*:attribute" value="instance('i-availableElements')/*[local-name() = local-name(current())]"/>
                        </xf:action>
                    </xf:select1>
                    <xf:trigger class="btn btn-outline-secondary btn-sm controls add" appearance="full" ref=".[instance('i-availableElements')/*[local-name() = local-name(current())][instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:availableAtts/descendant-or-self::*:attDef]]">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-plus-circle"></i> Attribute</xf:label>
                        <xf:insert ev:event="DOMActivate" context=".[not(name(@*) = instance('i-insert-attributes')//*:attribute)]" origin="instance('i-attributeTemplate')//@*[name(.) = instance('i-insert-attributes')//*:attribute]" position="after"></xf:insert>
                        <xf:setvalue ref="instance('i-insert-attributes')//*:attribute" value="''"/>
                        <xf:setvalue ref="instance('i-availableElements')/*" value="''"/>
                    </xf:trigger> 
                    <xf:select1 xmlns="http://www.w3.org/2002/xforms" ref="instance('i-availableElements')/*[local-name() = local-name(current())][instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:childElements[1]/*:child/*:element]">
                        <xf:label></xf:label>
                        <xf:item>
                            <xf:label> - select - </xf:label>
                            <xf:value/>
                        </xf:item>
                        <xf:itemset ref="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:childElements[1]/*:child/*:element">
                            <xf:label ref="@ident"/>
                            <xf:value ref="@ident"/>
                        </xf:itemset>
                        <xf:action ev:event="xforms-value-changed">                            
                            <xf:setvalue ref="instance('i-insert-elements')//*:element" value="instance('i-availableElements')/*[local-name() = local-name(current())]"/>
                        </xf:action>
                    </xf:select1>
                    <xf:trigger class="btn btn-outline-secondary btn-sm controls add" appearance="full" ref=".[instance('i-availableElements')/*[local-name() = local-name(current())][instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())]/*:childElements[1]/*:child/*:element]]">
                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-plus-circle"></i> Child Element</xf:label>
                        <xf:insert ev:event="DOMActivate" context="." at="." origin="instance('i-elementTemplate')//*[local-name() = instance('i-insert-elements')//*:element]" position="after"/>
                        <xf:setvalue ev:event="DOMActivate" ref="instance('i-insert-elements')//*:element"/>
                        <xf:setvalue ev:event="DOMActivate" ref="instance('i-availableElements')/*[local-name() = local-name(current())][instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())]/*:childElements[1]/*:child/*:element]"/>
                    </xf:trigger>
                    <xf:trigger appearance="minimal" 
                        ref=".[instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:lookup]" 
                        class="btn btn-outline-secondary btn-sm controls add showLookup">
                        <xf:label> <i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-search"></i> Lookup ??</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:toggle case="{$repeatID}LookupUnHide" ev:event="DOMActivate" />
                            <xf:load show="embed" targetid="{$repeatID}subformLookup">
                                <xf:resource value="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:lookup/@formURL"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                    <xf:trigger appearance="minimal" 
                        ref=".[instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:popup]" 
                        class="btn btn-outline-secondary btn-sm controls add showLookup">
                        <xf:label> <i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-search"></i> New  <xf:output value="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())]/@elementLabel"/>??</xf:label>
                        <xf:action ev:event="DOMActivate">
                            <xf:load show="new">
                                <xf:resource value="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:popup/@formURL"/>
                            </xf:load>
                        </xf:action>
                    </xf:trigger>
                    <xf:switch class="lookupSwitch" style="width:.5em;">
                        <xf:case id="{$repeatID}LookupHide" style="display:none;"></xf:case>
                        <xf:case id="{$repeatID}LookupUnHide">
                            <div class="lookupDisplay">
                                <xf:group id="{$repeatID}subformLookup"/>
                                <div class="text-right">
                                    <xf:trigger class="btn btn-outline-secondary btn-sm close" appearance="full" >
                                        <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-x-circle"/> Close</xf:label>
                                        <xf:toggle case="{$repeatID}LookupHide" ev:event="DOMActivate" />
                                        <xf:unload targetid="{$repeatID}subformLookup"/>
                                    </xf:trigger>   
                                </div>
                            </div>
                        </xf:case>
                    </xf:switch>
                </div>
            </div> 
        </div>
        <div class="element">   
            <div class="inlineDisplay btn-toolbar justify-content-between" role="toolbar">
                <xf:input class="elementInput" ref=".[(instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:childElements/*:textNode[@type='input']) or (not(child::*) and (instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())]/*:childElements/*:textNode[@type='input']))]"></xf:input>
                <xf:textarea class="elementTextArea" ref=".[instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())][1]/*:childElements/*:textNode[@type='textarea']]"></xf:textarea>  
                &#160;&#160;
                <xf:repeat ref="@*" xmlns="http://www.w3.org/2002/xforms"> 
                    <div class="btn-group" role="group" xmlns="http://www.w3.org/1999/xhtml">
                        <div class="input-group">
                            <xf:input ref=".[not(instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current()/parent::*)][1]/descendant-or-self::*:availableAtts/*:attDef[@ident = name(current())]/descendant-or-self::*:valList)]" class="attVal"></xf:input>
                            <xf:select1 ref=".[instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current()/parent::*)][1]/descendant-or-self::*:availableAtts/*:attDef[@ident = name(current())]/descendant-or-self::*:valList]" class="attVal">
                                <xf:itemset ref="instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current()/parent::*)][1]/descendant-or-self::*:availableAtts/*:attDef[@ident = name(current())]/descendant-or-self::*:valList/*:valItem" class="attVal">
                                    <xf:label ref="@ident"/>
                                    <xf:value ref="@ident"/>
                                </xf:itemset>
                            </xf:select1>
                            <xf:trigger class="btn btn-outline-secondary btn-sm controls" appearance="full" ref="." xmlns="http://www.w3.org/2002/xforms">
                                <xf:label><i xmlns="http://www.w3.org/1999/xhtml" class="bi bi-x-circle"/>&#160;<xf:output value="local-name(current())" xmlns="http://www.w3.org/2002/xforms"/></xf:label>
                                <xf:delete ev:event="DOMActivate" ref="."/>    
                            </xf:trigger>
                        </div>    
                    </div>
                    &#160;
                </xf:repeat>
            </div>
            
            <xsl:if test="$currentLevel &lt;= $maxLevel">
                <xsl:variable name="childRepeatID">
                    <xsl:choose>
                        <xsl:when test="$subform/parent::*:subform">
                            <xsl:value-of select="concat(string($subform/parent::*:subform/@formName),'Subform',$subformName,'RepeatLevel',if(string($currentLevel) != '') then string($currentLevel) else '1')"/></xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat($subformName,'RepeatLevel',if(string($currentLevel) != '') then string($currentLevel) else '1')"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xf:repeat id="{$childRepeatID}" ref="./*[instance('i-{$subformName}-schemaConstraints')/*[local-name() = local-name(current())]/*:childElements/*:child]">
                    <div class="nested">
                        <xsl:call-template name="xformElementUI">
                            <xsl:with-param name="subform" select="$subform"/>
                            <xsl:with-param name="xpath" select="concat($xpath,'/*')"/>
                            <xsl:with-param name="xpathIndex">
                                <xsl:choose>
                                    <xsl:when test="$repeatID != ''"><xsl:value-of select="replace($xpathIndex,'tei:','*:')"/>[index('<xsl:value-of select="$repeatID"/>')]/*</xsl:when>
                                    <xsl:when test="$subform/parent::*:subform and $currentLevel = 1">
                                        <xsl:value-of select="replace($xpathIndex,'tei:','*:')"/>
                                    </xsl:when>
                                    <xsl:otherwise><xsl:value-of select="replace($xpathIndex,'tei:','*:')"/>/*</xsl:otherwise>
                                </xsl:choose>
                            </xsl:with-param>
                            <xsl:with-param name="currentLevel" select="$currentLevel + 1"/>
                            <xsl:with-param name="maxLevel" select="$maxLevel"/>
                            <xsl:with-param name="repeatID" select="$childRepeatID"/>
                        </xsl:call-template>
                    </div>
                </xf:repeat>
            </xsl:if>
            
          
        </div>
    </xsl:template>
    
    <!-- Shared navbar -->
    <xsl:template name="navbar">
        <xsl:variable name="home" select="$app-root"/>
        <header class="navbar navbar-dark sticky-top bg-dark flex-md-nowrap p-0 shadow">
            <a class="navbar-brand col-md-3 col-lg-2 me-0 px-3" href="{$app-root}"><xsl:value-of select="$configDoc//formBrandName"/></a>
            <button class="navbar-toggler position-absolute d-md-none collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#sidebarMenu" aria-controls="sidebarMenu" aria-expanded="false" aria-label="Toggle navigation">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="navbar-nav">
                <div class="nav-item text-nowrap">
                    <a class="nav-link px-3" href="{$app-root}">Home</a>
                </div>
            </div>
        </header>
    </xsl:template>
     
    <!-- Build controlled values -->
    <xsl:template match="tei:elementSpec" mode="controlledValues">
        <xsl:if test="tei:attList/tei:attDef[tei:valList[@type = 'closed']]">
            <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                <xsl:for-each select="tei:attList/tei:attDef[tei:valList[@type = 'closed']]">
                    <xsl:element name="{string(@ident)}" namespace="http://www.tei-c.org/ns/1.0">
                        <xsl:copy-of select="tei:valList[@type = 'closed']"/>
                    </xsl:element>
                </xsl:for-each>
            </xsl:element>
        </xsl:if>
    </xsl:template>
  
    <!-- 
        This named templates is used to build a full example template to pull ALL elements from. 
        Adds all elements/attributes listed in global or local schemas
    -->
    <xsl:template name="elementTemplate">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:variable name="globalSchemaDoc">
                <xsl:for-each select="$configDoc//subform">
                    <xsl:copy-of select="document(globalSchema/@src)"/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="localSchemaDoc">
                <xsl:for-each select="$configDoc//subform">
                    <xsl:copy-of select="document(localSchema/@src)"/>
                </xsl:for-each>
            </xsl:variable> 
            <xsl:for-each-group select="$globalSchemaDoc//descendant-or-self::tei:elementSpec | $localSchemaDoc//descendant-or-self::tei:elementSpec" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                <xsl:element name="{current-grouping-key()}" namespace="http://www.tei-c.org/ns/1.0"/>
            </xsl:for-each-group>
        </TEI>
    </xsl:template>

    <xsl:template name="attributesTemplate">
        <xsl:variable name="globalSchemaDoc">
            <xsl:for-each select="$configDoc//subform">
                <xsl:copy-of select="document(globalSchema/@src)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="localSchemaDoc">
            <xsl:for-each select="$configDoc//subform">
                <xsl:copy-of select="document(localSchema/@src)"/>
            </xsl:for-each>
        </xsl:variable>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <element>
                <!-- Go through global and local schema, output one of every attribute -->
                <xsl:for-each-group select="$globalSchemaDoc//tei:attDef | $localSchemaDoc//tei:attDef" group-by="@ident">
                    <xsl:sort select="@ident" order="ascending"/>
                    <xsl:variable name="attName" select="@ident"/>
                    <xsl:attribute name="{$attName}"/>
                </xsl:for-each-group>
            </element>
        </TEI>
    </xsl:template>
    <xsl:template name="availableAttributes">
        <xsl:variable name="globalSchemaDoc">
            <xsl:for-each select="$configDoc//subform">
                <xsl:copy-of select="document(globalSchema/@src)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="localSchemaDoc">
            <xsl:for-each select="$configDoc//subform">
                <xsl:copy-of select="document(localSchema/@src)"/>
            </xsl:for-each>
        </xsl:variable>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <!-- Go through global and local schema, output one of every attribute -->
            <xsl:for-each-group select="$globalSchemaDoc//tei:attDef | $localSchemaDoc//tei:attDef" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                <xsl:element name="{current-grouping-key()}"/>
            </xsl:for-each-group>
        </TEI>
    </xsl:template>

    <!-- Create XForms bind rules based on schema constraints -->
    <xsl:template name="xformElementBind">
        <xsl:param name="elementName"/>
        <xsl:param name="subform"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>
        <xsl:param name="level"/>
        
        <xsl:variable name="elementRules" select="local:elementRules($elementName,$subform)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName,$subform)"/>
        <xsl:variable name="childElements" select="local:childElements($elementName,$subform)"/>
        <xsl:variable name="path" select="concat($path, '/tei:', $elementName)"/>
        <xsl:variable name="id" select="replace(replace(concat(replace($path,'/',''),generate-id(.)),' ',''),'tei:','')"/>
        <xsl:variable name="elementLabel">
            <xsl:choose>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = $formLang]">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = $formLang][1]"/>
                </xsl:when>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = 'en']">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = 'en'][1]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$elementName"/>
                </xsl:otherwise>
            </xsl:choose> 
        </xsl:variable>
        <xsl:variable name="maxOccur">
            <xsl:choose>
                <xsl:when test="$max != ''">
                    <xsl:value-of select="$max"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@maxOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@maxOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minOccur">
            <xsl:choose>
                <xsl:when test="$min != ''">
                    <xsl:value-of select="$min"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <xsl:when test="$maxOccur = 'unbounded' or $maxOccur = ''">repeat</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="elementRef">
            <xsl:choose>
                <xsl:when test="$level = 1">instance('i-rec')/<xsl:value-of select="$path"/></xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('tei:', $elementName)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xf:bind nodeset="{$elementRef}">
            <!-- Test if element is required, if minOccur is greater than 0 -->
            <xsl:if test="$minOccur castable as xs:integer">
                <xsl:if test="xs:integer($minOccur) &gt; 0">
                    <xsl:attribute name="required" select="'true()'"/>
                </xsl:if>
            </xsl:if>
            <!-- Get required attributes -->
            <xsl:for-each select="$allAttributes//*[@usage='req']">
                <xf:bind nodeset="@{@ident}" required="true()"/>
            </xsl:for-each>
            <!-- Test for type -->
            <!-- Test for any constraints -->
            <!--
            <xsl:for-each select="$elementRules/descendant-or-self::tei:constraintSpec">
                
            </xsl:for-each>
            -->
            <!-- get other child elements -->
            <xsl:if test="$childElements/descendant-or-self::*:element[not(@classRef = 'true')] and $elementName != 'p'">
                <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]" group-by="@ident">
                    <xsl:if test="$elementName != current-grouping-key() and not(contains($path,'current-grouping-key()'))">
                        <xsl:call-template name="xformElementBind">
                            <xsl:with-param name="elementName" select="current-grouping-key()"/>
                            <xsl:with-param name="subform" select="$subform"/>
                            <xsl:with-param name="path" select="$path"/>
                            <xsl:with-param name="min" select="@minOccurs"/>
                            <xsl:with-param name="max" select="@maxOccurs"/>
                            <xsl:with-param name="level" select="xs:integer($level) + 1"/>
                        </xsl:call-template>
                    </xsl:if>
                </xsl:for-each-group>
            </xsl:if>
        </xf:bind>        
    </xsl:template>
   
    <!-- Full list of schema rules -->
    <xsl:template name="generateSchemaInstance">
        <xsl:param name="subform"/>
        <xsl:variable name="elementName" select="substring-after(tokenize($subform/@xpath,'/')[last()],':')"/>
        <xsl:variable name="mainFormName" select="$configDoc//formName"/>
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:call-template name="xformElementSchemaInstance">
                <xsl:with-param name="elementName" select="$elementName"/>
                <xsl:with-param name="parentElementName"/>
                <xsl:with-param name="subform" select="$subform"/>
                <xsl:with-param name="path"/>
                <xsl:with-param name="min"/>
                <xsl:with-param name="max"/>
                <xsl:with-param name="level">0</xsl:with-param>
            </xsl:call-template> 
        </TEI>
        <!--
        <xsl:if test="$subform/xmlTemplate/@src">
            <xsl:variable name="mainFormName" select="$configDoc//formName"/>
            <xsl:variable name="xpath">
                <xsl:choose>
                    <xsl:when test="$subform/parent::*:subform">
                        <xsl:value-of select="concat($subform/parent::*:subform/@xpath,'/',string($subform/@xpath))"/>
                    </xsl:when>
                    <xsl:otherwise><xsl:value-of select="string($subform/@xpath)"/></xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="template" select="document($subform/xmlTemplate/@src)"/>
            <xsl:variable name="subsequence">
                <xsl:evaluate xpath="$xpath" context-item="$template"/>
            </xsl:variable>
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:for-each select="$subsequence/element()">
                    <xsl:variable name="elementPath" select="replace(replace(replace(replace(path(.), 'Q\{http://www.tei-c.org/ns/1.0\}', 'tei:'), 'tei:TEI', '/'), '\[[0-9]+\]', ''), '///', '//')"/>
                    <xsl:variable name="elementName" select="local-name(.)"/>
                    <xsl:call-template name="xformElementSchemaInstance">
                        <xsl:with-param name="elementName" select="$elementName"/>
                        <xsl:with-param name="parentElementName"/>
                        <xsl:with-param name="subform" select="$subform"/>
                        <xsl:with-param name="path"/>
                        <xsl:with-param name="min"/>
                        <xsl:with-param name="max"/>
                        <xsl:with-param name="level">0</xsl:with-param>
                    </xsl:call-template>
                </xsl:for-each>
            </TEI>
        </xsl:if>
        -->
     </xsl:template>
    <xsl:template name="xformElementSchemaInstance">
        <xsl:param name="elementName"/>
        <xsl:param name="parentElementName"/>
        <xsl:param name="subform"/>
        <xsl:param name="path"/>
        <xsl:param name="min"/>
        <xsl:param name="max"/>
        <xsl:param name="level"/>
        
        <xsl:variable name="subformName" select="$subform/@formName"></xsl:variable>
        <xsl:variable name="elementRules" select="local:elementRules($elementName,$subformName)"/>
        <xsl:variable name="allAttributes" select="local:allAttributes($elementName,$subformName)"/>
        <xsl:variable name="childElements" select="local:childElements($elementName,$subformName)"/>
        <xsl:variable name="siblingElements" select="local:siblingElements($parentElementName, $elementName,$subformName)"/>
        <xsl:variable name="path" select="concat($path, '/*:', $elementName)"/>
        <xsl:variable name="id" select="replace(replace(concat(replace($path,'/',''),generate-id(.)),' ',''),'\*:','')"/>
        <xsl:variable name="elementLabel">
            <xsl:choose>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = $formLang]">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = $formLang][1]"/>
                </xsl:when>
                <xsl:when test="$elementRules/descendant::tei:gloss[@xml:lang = 'en']">
                    <xsl:value-of select="$elementRules/descendant::tei:gloss[@xml:lang = 'en'][1]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$elementName"/>
                </xsl:otherwise>
            </xsl:choose> 
        </xsl:variable>
        <xsl:variable name="maxOccur">
            <xsl:choose>
                <xsl:when test="$max != ''">
                    <xsl:value-of select="$max"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@maxOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@maxOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minOccur">
            <xsl:choose>
                <xsl:when test="$min != ''">
                    <xsl:value-of select="$min"/>
                </xsl:when>
                <xsl:when test="$elementRules/tei:content/tei:sequence[@minOccur]">
                    <xsl:value-of select="string($elementRules/tei:content/tei:sequence/@minOccur)"/>
                </xsl:when>
                <xsl:otherwise/>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="xformsElement">
            <xsl:choose>
                <!--                <xsl:when test="$maxOccur = 'unbounded' or $maxOccur = ''">repeat</xsl:when>-->
                <xsl:when test="$maxOccur = 'unbounded' or $maxOccur = ''">group</xsl:when>
                <xsl:otherwise>group</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="elementRef">
            <xsl:choose>
                <xsl:when test="$xformsElement = 'repeat'">
                    <xsl:choose>
                        <xsl:when test="$level = 1">instance('i-rec')/<xsl:value-of select="$path"/>/*</xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat('*:', $elementName,'/*')"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:when test="$level = 1">instance('i-rec')/<xsl:value-of select="$path"/></xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="concat('*:', $elementName)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="currentLevel">
            <xsl:choose>
                <xsl:when test="$level castable as xs:integer"><xsl:value-of select="xs:integer($level) + 1"/></xsl:when>
                <xsl:otherwise>1</xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:element name="{$elementName}" namespace="http://www.tei-c.org/ns/1.0">
            <xsl:attribute name="ident" select="$elementName"/>
            <xsl:attribute name="elementName" select="$elementName"/>
            <xsl:attribute name="elementLabel" select="$elementLabel"/>
            <xsl:attribute name="minOccur" select="$minOccur"/>
            <xsl:attribute name="maxOccur" select="$maxOccur"/>
            <xsl:attribute name="path" select="$path"/>
            <xsl:attribute name="currentLevel" select="$currentLevel"/>
            <xsl:attribute name="popup" select="$currentLevel"/>
            <xsl:if test="$configDoc/descendant::*:lookup[@elementName = $elementName]">
                <lookup>
                    <xsl:copy-of select="$configDoc/descendant::*:lookup[@elementName = $elementName]/@*"/>
                    <xsl:attribute name="formURL" select="concat('form.xq?form=forms/',$configDoc//formName/text(),'/lookup/',$elementName,'.xhtml')"></xsl:attribute>
                </lookup>
            </xsl:if>      
            <xsl:if test="$configDoc/descendant::*:popup[@elementName = $elementName]">
                <popup>
                    <xsl:copy-of select="$configDoc/descendant::*:popup[@elementName = $elementName]/@*"/>
                    <xsl:attribute name="formURL" select="concat('form.xq?form=forms/',$configDoc/descendant::*:popup[@elementName = $elementName]/@formName,'/index.xhtml')"></xsl:attribute>
                </popup>
            </xsl:if>  
            <xsl:if test="$elementRules/descendant::tei:desc">
                <desc xmlns="http://www.tei-c.org/ns/1.0">
                    <xsl:choose>
                        <xsl:when test="$formLang != ''">
                            <xsl:choose>
                                <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = $formLang]">
                                    <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = $formLang][1]"/>
                                </xsl:when>
                                <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = 'en']">
                                    <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = 'en'][1]"/>
                                </xsl:when>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="$elementRules/descendant::tei:desc[@xml:lang = 'en']">
                            <xsl:value-of select="$elementRules/descendant::tei:desc[@xml:lang = 'en'][1]"/>
                        </xsl:when>
                    </xsl:choose>
                </desc>
            </xsl:if>
            <xsl:copy-of select="$allAttributes"/>
            <childElements xmlns="http://www.tei-c.org/ns/1.0">
                <xsl:choose>
                    <xsl:when test="$elementRules/descendant-or-self::*:content/descendant-or-self::*:textNode">
                        <xsl:choose>
                            <xsl:when test="$elementName = ('p','desc','note','summary')">
                                <textNode type="textarea"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <textNode type="input"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:when test="not($childElements/child::*)">
                        <textNode type="input"/>
                    </xsl:when>
                </xsl:choose>
                <xsl:copy-of select="$childElements"/>
            </childElements>
        </xsl:element>
        <xsl:if test="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]">
            <xsl:for-each-group select="$childElements/descendant-or-self::*:element[not(@classRef = 'true')]" group-by="@ident">
                <xsl:variable name="numMatch" select="count(tokenize($path, concat('/*:',$elementName))) - 1"/>
                <xsl:choose>
                    <xsl:when test="($elementName = current-grouping-key() or contains($path,current-grouping-key())) and $numMatch gt 2"/>
                    <xsl:otherwise>
                        <xsl:call-template name="xformElementSchemaInstance">
                            <xsl:with-param name="elementName" select="current-grouping-key()"/>
                            <xsl:with-param name="parentElementName" select="$elementName"/>
                            <xsl:with-param name="subform" select="$subform"/>
                            <xsl:with-param name="path" select="$path"/>
                            <xsl:with-param name="min" select="@minOccurs"/>
                            <xsl:with-param name="max" select="@maxOccurs"/>
                            <xsl:with-param name="level" select="$currentLevel"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
                
                <!-- 
                <xsl:if test="$elementName != current-grouping-key() and not(contains($path,'current-grouping-key()'))">
                    <xsl:call-template name="xformElementSchemaInstance">
                        <xsl:with-param name="elementName" select="current-grouping-key()"/>
                        <xsl:with-param name="parentElementName" select="$elementName"/>
                        <xsl:with-param name="subform" select="$subform"/>
                        <xsl:with-param name="path" select="$path"/>
                        <xsl:with-param name="min" select="@minOccurs"/>
                        <xsl:with-param name="max" select="@maxOccurs"/>
                        <xsl:with-param name="level" select="$currentLevel"/>
                    </xsl:call-template>
                </xsl:if>
                -->
            </xsl:for-each-group>
        </xsl:if>
    </xsl:template>

    <!--
    <xsl:template name="XMLSkeleton">
        <TEI xmlns="http://www.tei-c.org/ns/1.0">
            <xsl:variable name="globalSchemaDoc">
                <xsl:for-each select="$configDoc//subform">
                    <xsl:copy-of select="document(globalSchema/@src)"/>
                </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="localSchemaDoc">
                <xsl:for-each select="$configDoc//subform">
                    <xsl:copy-of select="document(localSchema/@src)"/>
                </xsl:for-each>
            </xsl:variable> 
            <xsl:for-each-group select="$globalSchemaDoc//descendant-or-self::tei:elementSpec | $localSchemaDoc//descendant-or-self::tei:elementSpec" group-by="@ident">
                <xsl:sort select="current-grouping-key()"/>
                <xsl:element name="{current-grouping-key()}" namespace="http://www.tei-c.org/ns/1.0"/>
            </xsl:for-each-group>
        </TEI>
    </xsl:template>
    -->
    
</xsl:stylesheet>

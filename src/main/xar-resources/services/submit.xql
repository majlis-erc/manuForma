xquery version "3.1";
(:~
 : Submit XForms generated data.
 :
 : HTTP Request Parameters:
 : @request-parameter eXistCollection The db path to the data collection
 : @request-parameter type The type of action to perform: <dl>
       <dt>save</dt>          <dd>Save to db. Only available to logged in users</dd>
       <dt>github</dt>        <dd>Commit to git and save to db. Only available to logged in users</dd>
       <dt>download</dt>      <dd>Download xml without saving</dd>
       <dt>view</dt>          <dd>View XML in new window</dd>
       <dt>previewHTML</dt>   <dd>View HTML preview</dd>
       <dt>upload</dt>        <dd>View the processed XML</dd>
 </dl>
 : @request-parameter new true if this is a new record, or false if editing an existing record
 : @request-parameter postdata the form data, if absent then the body of the request will be used
 : @request-parameter githubPath the path within the git repo to commit to
 : @request-parameter githubRepo the name of the GitHub repo
 :)
import module namespace config = "http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit = "http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
import module namespace rh = "http://localhost/manuForma/request-helper" at "../modules/request-helper.xqm";

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

declare option output:method "xml";
declare option output:media-type "application/xml";
declare option output:omit-xml-declaration "no";
declare option output:indent "yes";

declare variable $local:exist-collection-path as xs:string := rh:request-param('eXistCollection', concat($config:app-root, '/data'));
declare variable $local:type as xs:string? := rh:request-param('type');
declare variable $local:new as xs:boolean := rh:request-param-bool("new");
declare variable $local:data := rh:request-param('postdata', request:get-data());
declare variable $local:github-path as xs:string := rh:request-param('githubPath', 'data/tei/');
declare variable $local:github-repo as xs:string := rh:request-param('githubRepo', 'blogs');

declare variable $local:user-id as xs:string := (request:get-attribute("org.exist.login.user"), sm:id()/sm:id/sm:real/sm:username/string(.))[1];
declare variable $local:user-name as xs:string := sm:get-account-metadata($local:user-id, xs:anyURI('http://axschema.org/namePerson'));

declare function local:extract-id-from-uri($uri as xs:string) as xs:integer {
    let $part := tokenize($uri, '/')[last()]
    return
        if ($part castable as xs:integer)
        then
            xs:integer($part)
        else
            0
};

declare function local:create-id() as xs:string {
    let $base-uri := 
            if (contains($local:exist-collection-path, "/manuscripts/")) then
                "https://jalit.org/manuscript/"
            else if (contains($local:exist-collection-path, "/persons/")) then
                "https://jalit.org/person/"
            else if (contains($local:exist-collection-path, "/works/")) then
                "https://jalit.org/work/"
            else if (contains($local:exist-collection-path, "/places/")) then
                "https://jalit.org/place/"
            else if (contains($local:exist-collection-path, "/relations/")) then
                "https://jalit.org/relation/"                
            else
                "https://jalit.org/"
    let $last-id := max(
        collection($local:exist-collection-path)//tei:idno[@type eq 'URI'][parent::tei:publicationStmt]/local:extract-id-from-uri(.)
    )
    let $new-id := $last-id + 1
    return
        concat($base-uri, $new-id)
};

(: Any post processing to TEI form data happens here :)
declare function local:transform($new as xs:boolean, $id as xs:string, $uri as xs:string?, $nodes as node()*) as item()* {
    for $node in $nodes
    return
        typeswitch($node)

            case processing-instruction()
            return
                $node

            case comment() 
            return
                $node

            case text()
            return
                $node

            case element(tei:TEI)
            return 
                element {node-name($node)} {
                    $node/@*[name(.) ne 'class'],
                    local:transform($new, $id, $uri, $node/node())
                }

            case element(tei:desc)
            return
                element {node-name($node)} {
                    $node/@*,
                    local:markdown2TEI($node/node())
                }

            case element(tei:note)
            return
                element {node-name($node)} {
                    $node/@*,
                    (: NOTE(AR) workaround for max as tei:note has multiple child nodes :)
                    (: local:markdown2TEI($node/node()) :)
                    for $child in $node/node()
                    return
                        local:markdown2TEI($child)
                }

            case element(tei:summary)
            return
                if ($node[parent::tei:layoutDesc]) then
                    local:passthru($new, $id, $uri, $node)
                else
                    element {node-name($node)} {
                        $node/@*,
                        local:markdown2TEI($node/node())
                    }

            case element(tei:quote)
            return 
                element {node-name($node)} {
                    $node/@*,
                    local:markdown2TEI($node/node())
                }

            case element(tei:p)
            return 
                if ($node[ancestor::tei:note] or $node[ancestor::tei:desc] or $node[ancestor::tei:summary] or $node[ancestor::tei:ab]) then
                    element {node-name($node)} {
                        $node/@*,
                        local:markdown2TEI($node/node())
                    }
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:ab)
            return
                if ($node[@type eq 'factoid'][@subtype eq 'relation']) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('factoid-', $id ))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:titleStmt)
            return
                element {node-name($node)} {
                    local:attrs-updated-source($node/@*),
                    local:transform($new, $id, $uri, $node/tei:title),
                    local:transform($new, $id, $uri, $node/tei:author),
                    local:transform($new, $id, $uri, $node/tei:sponsor),
                    local:transform($new, $id, $uri, $node/tei:funder),
                    local:transform($new, $id, $uri, $node/tei:principal),
                    local:transform($new, $id, $uri, $node/tei:editor[exists((text(), @ref)[normalize-space(.) ne ""])]),
                    if ($local:user-id ne 'guest' and empty($node[tei:editor[. eq $local:user-name]])) then
                        <tei:editor xml:id="{$local:user-id}" role="contributor">{$local:user-name}</tei:editor>
                    else (),
                    local:transform($new, $id, $uri, $node/tei:meeting),
                    local:transform($new, $id, $uri, $node/tei:respStmt)
                }

            case element(tei:idno)
            return
                if ($node[parent::tei:ab[@type eq 'factoid'][@subtype eq 'relation']]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('name-', count($node/preceding-sibling::tei:idno) + 1))
                else if ($new and $node[parent::tei:publicationStmt]) then
                    element {node-name($node)} {
                        $node/@*,
                        $uri
                    }
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:place)
            return
                if ($node[parent::tei:listPlace]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('place-', $id))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:placeName)
            return
                if ($node[parent::tei:place/parent::tei:listPlace]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, count($node/preceding-sibling::tei:placeName) + 1)
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:bibl)
            return
                if ($node[parent::tei:place/parent::tei:listPlace] or $node[parent::tei:person/parent::tei:listPerson] or $node[parent::tei:note/parent::tei:bibl/parent::tei:body] or $node[parent::tei:bibl/parent::tei:bibl/parent::tei:body]) then
                    element {node-name($node)} {
                        (:attribute xml:id { concat('bibl-', count($node/preceding-sibling::tei:bibl) + 1) },:)
                        $node/@*[name(.) ne 'source'],
                        $node/node() ! local:transform($new, $id, $uri, .)
                    } 
                else if ($node[parent::tei:body/parent::tei:text]) then
                    element {node-name($node)} {
                        (:attribute xml:id { concat('work-', $id) },:)
                        $node/@*[name(.) ne 'source'],
                        $node/node() ! local:transform($new, $id, $uri, .)
                    }
                else if ($node[parent::tei:listBibl/parent::tei:additional/parent::tei:msDesc]) then
                    element {node-name($node)} {
                        (:attribute xml:id { concat('bibl-',
                        count($node/parent::tei:listBibl/parent::tei:additional/preceding-sibling::tei:additional) + 1,
                        '.',
                        count($node/parent::tei:listBibl/preceding-sibling::tei:listBibl) + 1,
                        '.',
                        count($node/preceding-sibling::tei:bibl) + 1)
                        },:)
                        $node/@*[name(.) ne 'source'],
                        $node/node() ! local:transform($new, $id, $uri, .)
                    }
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:title)
            return
                if ($node[exists((text(), @ref)[normalize-space(.) ne ""])])
                then
                    if ($node[parent::tei:bibl/parent::tei:body]) then
                        local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('title-', count($node/preceding-sibling::tei:title) + 1))
                    else
                        local:passthru($new, $id, $uri, $node)
                else ()

            case element(tei:person)
            return
                if ($node[parent::tei:listPerson]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('person-', $id ))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:persName)
            return
                if ($node[parent::tei:person/parent::tei:listPerson]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('name-', count($node/preceding-sibling::tei:persName) + 1))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:msDesc)
            return
                local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('ms-',$id))

            case element(tei:msItem)
            return
                if ($node[parent::tei:msContents/parent::tei:msDesc]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('item-',
                            count($node/parent::tei:msContents/preceding-sibling::tei:msContents) + 1,
                            '.',
                            count($node/preceding-sibling::tei:msItem) + 1
                    ))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:layout)
            return
                if ($node[parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/parent::tei:msDesc]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('layout-',
                                count($node/parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1,
                                '.',
                                count($node/parent::tei:layoutDesc/parent::tei:objectDesc/preceding-sibling::tei:objectDesc) + 1,
                                '.',
                                count($node/parent::tei:layoutDesc/preceding-sibling::tei:layoutDesc) + 1,
                                '.',
                                count($node/preceding-sibling::tei:layout) + 1
                    ))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:handNote)
            return
                if ($node[parent::tei:handDesc/parent::tei:physDesc/parent::tei:msDesc]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('hand-',
                                count($node/parent::tei:handDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1,
                                '.',
                                count($node/parent::tei:handDesc/preceding-sibling::tei:handDesc) + 1,
                                '.',
                                count($node/preceding-sibling::tei:handNote) + 1
                    ))
                else
                    local:passthru($new, $id, $uri, $node)

            case element(tei:item)
            return
                if ($node[parent::tei:list/parent::tei:additions/parent::tei:physDesc/parent::tei:msDesc]) then
                    local:copy-with-new-id-and-updated-source($new, $id, $uri, $node, concat('add-',
                                count($node/parent::tei:list/parent::tei:additions/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1,
                                '.',
                                count($node/parent::tei:list/parent::tei:additions/preceding-sibling::tei:additions) + 1,
                                '.',
                                count($node/parent::tei:list/preceding-sibling::tei:list) + 1,
                                '.',
                                count($node/preceding-sibling::tei:item) + 1
                    ))
                else
                    local:passthru($new, $id, $uri, $node)

(:
            case element(tei:revisionDesc)
            return 
                element {node-name($node)} {
                    $node/@*[. ne ''],
                    local:transform($node/node())),
                    <tei:change when="{current-dateTime()}" who="#{string($local:user-id)}" test="{concat($config:nav-base,'/userInfo')}">XForms Editing by {string($local:user-id)}</tei:change>
                }         
:)

            case element(tei:relation)
            return
                if ($node[tei:mutual or tei:active or tei:passive]) then
                    element {node-name($node)} {
                        $node/@*[not(local-name(.) = ('active', 'mutual', 'passive'))],
                        attribute active { string-join($node/tei:active/@ref, ' ') },
                        attribute mutual { string-join($node/tei:mutual/@ref, ' ') },
                        attribute passive { string-join($node/tei:passive/@ref, ' ') }
                    }
                else
                    local:passthru($new, $id, $uri, $node)

            case element()
            return
                local:passthru($new, $id, $uri, $node)

            default
            return
                local:transform($new, $id, $uri, $node/node())
};

(: Recurse through child nodes :)
declare function local:passthru($new as xs:boolean, $id as xs:string, $uri as xs:string?, $node as node()*) as item()* {
    element {node-name($node)} {
        local:attrs-updated-source($node/@*),
        local:transform($new, $id, $uri, $node/node())
    }
};

declare function local:copy-with-new-id-and-updated-source($new as xs:boolean, $id as xs:string, $uri as xs:string?, $node as node(), $new-xml-id as xs:string) as element() {
  element {node-name($node)} {
      attribute xml:id { $new-xml-id },
      local:attrs-updated-source($node/@*[name(.) ne "xml:id"]),
      $node/node() ! local:transform($new, $id, $uri, .)
  }
};

declare function local:attrs-updated-source($attrs as attribute()*) as attribute()* {
    (
        if ($attrs/self::attribute(source)[. ne '']) then
            attribute source {concat('#', substring-after($attrs/self::attribute(source), '#'))}
        else (),
        $attrs[name(.) ne 'source']
    )
};

(: Markdown to TEI :)
declare function local:markdown2TEI($node) as element(tei:p)* {
    if (count($node) gt 1)
    then
        (: <document>{root($n)}</document> :)
        let $nodes := for $n in $node return <node uri="{document-uri(root($n))}">{$n}</node>
        return
            util:log("INFO", ("PROBLEM: ", <nodes>{$nodes}</nodes>, <parent>{$node[1]/parent::node()}</parent>))
    else(),
    
    for $l in tokenize($node, '\n\n')
    return
        <tei:p>{local:lineBreak($l)}</tei:p>
};
    
declare function local:lineBreak($s) {
    for $node in fn:analyze-string($s, "(.*?)\n")/child::*
    return 
        typeswitch($node)
            case element(fn:match) return (local:markdown($node), <tei:lb/>)
            default return local:markdown($node/node())
};

declare function local:markdown($s) {
    for $node in fn:analyze-string($s, "\*(.*?)\*")/child::*
    return 
        typeswitch($node)
            case element(fn:match) return <tei:em>{$node/fn:group/node()}</tei:em>
            default return $node/node()
};  

declare function local:save($id as xs:string?, $file-name as xs:string, $post-processed-xml) as element(response) {
    try {
        let $save := xmldb:store($local:exist-collection-path, xmldb:encode-uri($file-name), $post-processed-xml)
        return 
            <response status="okay" code="200">
                <message>{$save} Record {$id} saved, thank you for your contribution.</message>
            </response>  
    } catch * {
        let $_ := util:log("ERROR", concat("Failed to update resource: ", $id, ". [", $err:line-number, ":", $err:column-number, "]", $err:module, ": ", $err:code, " ", $err:description))
        return
          <response status="fail" code="500">
              <message>Failed to update resource: {$id}. {concat($err:code, ": ", $err:description)}</message>
          </response>
    }
};

declare function local:git-commit($file-name as xs:string, $post-processed-xml) as element(response) {
    try {
        let $save := gitcommit:run-commit($post-processed-xml, concat($local:github-path, $file-name), concat("User submitted content for ", $file-name))
        let $save-db := xmldb:store($local:exist-collection-path, xmldb:encode-uri($file-name), $post-processed-xml)
        return
            <response status="okay" code="200">
                <message>Record saved to the {$local:github-repo} GitHub. Thank you for your contribution.</message>
                <existURL>{$save-db}</existURL>
                <url>{$save}</url>
            </response>
    } catch * {
        let $_ := util:log("ERROR", concat("Failed to submit, please download your changes and send via email. [", $err:line-number, ":", $err:column-number, "]", $err:module, ": ", $err:code, " ", $err:description))
        return
            <response status="fail" code="500">
                <message>Failed to submit, please download your changes and send via email. {concat($err:code, ": ", $err:description)}</message>
            </response>
    }  
};

declare function local:preview-html($post-processed-xml) as element(response) {
    <response status="okay" code="200" type="html">
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>Preview TEI Record</title>
                <link rel="stylesheet" type="text/css" href="/exist/rest/apps/majlis/resources/bootstrap/css/bootstrap.min.css"/>
                <link rel="stylesheet" type="text/css" href="/exist/rest/apps/majlis/resources/css/sm-core-css.css"/>
                <link rel="stylesheet" type="text/css" href="/exist/rest/apps/majlis/resources/css/style.css"/>
                <link rel="stylesheet" type="text/css" href="/exist/rest/apps/majlis/resources/css/majlis.css"/>
                <link href="/exist/rest/apps/majlis/resources/jquery-ui/jquery-ui.min.css" rel="stylesheet"/>
            </head>
            <body>
                <h1>Record preview</h1>
                <div class="record">
                {
                  transform(map {
                          "source-node": $post-processed-xml,
                          "stylesheet-node": doc('/db/apps/majlis/resources/xsl/tei2html.xsl'),
                          "stylesheet-params": map {
                              "data-root": "/db/apps/majlis-data/data",
                              "app-root": "/db/apps/majlis",
                              "nav-base": "majlis",
                              "base-uri": "https://jalit.org"
                          }
                  })
                }
                </div>
            </body>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/js/jquery.min.js">&#160;</script>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/jquery-ui/jquery-ui.min.js">&#160;</script>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/bootstrap/js/bootstrap.min.js">&#160;</script>
        </html>
    </response>
};


let $uri as xs:string? := 
        if ($local:new) then 
            local:create-id() 
        else ()
let $id as xs:string? :=
        if ($local:new) then
            tokenize($uri, "/")[last()][. ne ""]
        else
            tokenize($local:data//tei:idno[parent::tei:publicationStmt][@type eq "URI"][1], "/")[last()]

let $post-processed-xml := local:transform($local:new, $id, $uri, $local:data)
return

    let $uri as xs:string := replace($post-processed-xml/descendant::tei:idno[1], "/tei", "")
    let $id as xs:string? := (tokenize($uri, "/")[last()])[. ne ""]
    let $file-name as xs:string := 
            if ($id) then
                concat($id, ".xml")
            else
                "form.xml"
    return
        
        (: Route and process the request based on the 'type' parameter :)
        let $response :=
          switch ($local:type)
            case "save" return local:save($id, $file-name, $post-processed-xml)
            case "github" return local:git-commit($file-name, $post-processed-xml)
            case "download" return (
                    response:set-header("Content-Type", "application/xml; charset=utf-8"),
                    response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),
                    $post-processed-xml
            )
            case "view" return (
                    response:set-header("Content-Type", "application/xml; charset=utf-8"),
                    $post-processed-xml
            )
            case "previewHTML" return local:preview-html($post-processed-xml)
            case "upload" return <data>{$post-processed-xml}</data>
            default return <response status="fail" code="400"><message>Bad request, type parameter missing</message></response>
        return
            (
                if ($response/@code)
                then
                    response:set-status-code(xs:integer($response/@code))
                else ()
                ,
                if ($response/@type = "html")
                then
                    response:stream($response/xhtml:html, "method=html media-type=text/html")
                else
                  $response
            )

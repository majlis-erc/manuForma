xquery version "3.1";
(:~
 : Get data for TEI XForms
 : 
:)
import module namespace config = "http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit = "http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
import module namespace rh = "http://localhost/manuForma/request-helper" at "../modules/request-helper.xqm";

import module namespace http = "http://expath.org/ns/http-client";
import module namespace request = "http://exist-db.org/xquery/request";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare option output:method "xml";
declare option output:media-type "application/xml";
declare option output:omit-xml-declaration "no";
declare option output:indent "yes";

declare variable $local:start as xs:string := rh:request-param("start", "1");
declare variable $local:search-uri as xs:string := rh:request-param("searchURI", "http://localhost:8080/exist/apps/majlis/modules/content-negotiation/content-negotiation.xql?results=manuForma");
declare variable $local:post-data as xs:string? := rh:request-param("postdata");
declare variable $local:template as xs:boolean := rh:request-param-bool("template");
declare variable $local:path as xs:string? := rh:request-param("path");
declare variable $local:search as xs:boolean := rh:request-param-bool("search");
declare variable $local:view as xs:string? := rh:request-param("view");
declare variable $local:q as xs:string? := rh:request-param("q");
declare variable $local:facets as map(xs:string, xs:string*)* := rh:request-params("facet");
declare variable $local:idno as xs:string? := rh:request-param("idno");
declare variable $local:base-uri as xs:string? := rh:request-param("baseURI");
declare variable $local:github as xs:string? := rh:request-param("github");
declare variable $local:exist-collection-path as xs:string := rh:request-param("eXistCollection", concat($config:app-root, "/data"));


(: Recurse through child nodes :)
declare function local:markdown($nodes as node()*) as item()* { 
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
                normalize-space($node)

            case element(tei:p)
            return
                if ($node[parent::tei:quote] or $node[parent::tei:summary] or $node[parent::tei:note] or $node[parent::tei:desc] or $node[parent::tei:ab]) then
                    if ($node[following-sibling::tei:p]) then
                        (
                            local:markdown($node/node()),
                            "&#10;&#10;"
                        )
                    else
                        local:markdown($node/node())
                else
                    local:passthru($node)

            case element(tei:lb)
            return
                "&#10;"

            case element(tei:em)
            return
                (
                    "*",
                    local:markdown($node/node()),
                    "*"
                )

            case element(tei:relation)
            return
                if ($node[exists((@active, @mutual, @passive))]) then
                    element {node-name($node)} {
                        $node/@*[not(local-name(.) = ('active', 'mutual', 'passive'))],
                        for $ref in tokenize($node/@active, " ")[. ne ""]
                        let $label := local:get-label($ref)
                        return
                            <tei:active ref="{$ref}">{$label}</tei:active>
                        ,
                        for $ref in tokenize($node/@passive, " ")[. ne ""]
                        let $label := local:get-label($ref)
                        return
                            <tei:mutual ref="{$ref}">{$label}</tei:mutual>
                        ,
                        for $ref in tokenize($node/@mutual, " ")[. ne ""]
                        let $label := local:get-label($ref)
                        return
                            <tei:passive ref="{$ref}">{$label}</tei:passive>
                        ,
                        local:markdown($node/node())
                    }

                else
                    local:passthru($node)

            case element()
            return
                local:passthru($node)

            default
            return
                local:markdown($node/node())
};

(: Recurse through child nodes :)
declare function local:passthru($node as node()*) as item()* { 
    element {node-name($node)} {
        $node/@*,
        local:markdown($node/node())
    }
};

declare function local:get-label($ref as xs:string) as xs:string {
    let $collection := "/db/apps/majlis-data/data"
    let $doc := (collection($collection)//tei:idno[@type eq "URI"][. = ($ref, concat($ref, "/"), concat($ref, "/tei"))]/ancestor::tei:TEI)[1]
    let $label := $doc/descendant::tei:title[1]/descendant-or-self::text()
    return
        normalize-space($label)
};

declare function local:get-data() {
    if (exists($local:post-data)) then
        $local:post-data

    else if ($local:template and exists($local:path)) then
            if (starts-with($local:path, "/db/") or contains($local:path, $config:app-root)) then
                doc($local:path)
            else
                doc($config:app-root || $local:path)

    else if ($local:search) then
        if ($local:view = "all") then
            <data>
            {
                for $r in collection($local:exist-collection-path)//tei:TEI
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type eq "URI"][1])
                order by $title
                return
                    <record src="{document-uri(root($r))}" name="{$title}" idno="{concat("[", $idno, "]")}"/>
            }
            </data>

        else if (exists($local:q)) then
            <data>
            {
                let $facet-params := $local:facets ! ("&amp;" || .?name || "=" || escape-uri(.?value, true()))
                let $url := $local:search-uri || "&amp;q=" || escape-uri($local:q, true()) || "&amp;existCollection=" || $local:exist-collection-path || "&amp;start=" || $local:start || $facet-params
                let $hits := http:send-request(<http:request http-version="1.1" href="{xs:anyURI($url)}" method="get"/>)
                return
                    $hits
            }
            </data>

        else if (exists($local:idno)) then
            let $idno as xs:string :=
                    if (starts-with($local:idno, "http")) then
                        $local:idno
                    else if (exists($local:base-uri)) then
                        concat($local:base-uri, $local:idno)
                    else
                        concat("/", $local:idno)
            return
                <data idno="{$idno}">
                {
                    for $idno in collection($local:exist-collection-path)//tei:idno[. = ($idno, concat($idno, "/tei")) or ends-with(., $idno)]
                    let $title := string($idno/ancestor::tei:TEI/descendant::tei:title[1])
                    order by $title
                    return
                        <record src="{document-uri(root($idno))}" name="{$title}" idno="{concat("[", $idno, "]")}"/>
                }
                </data>

        else ()

    else if ($local:github = "browse") then
        gitcommit:list-files()

    else
        request:get-data()
};


let $data := local:get-data()
return
    local:markdown($data)

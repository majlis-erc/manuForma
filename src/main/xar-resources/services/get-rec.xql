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
import module namespace response = "http://exist-db.org/xquery/response";

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
declare function local:markdown($nodes as node()*, $labels as element(labels)?) as item()* {
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
                            local:markdown($node/node(), $labels),
                            "&#10;&#10;"
                        )
                    else
                        local:markdown($node/node(), $labels)
                else
                    local:passthru($node, $labels)

            case element(tei:lb)
            return
                "&#10;"

            case element(tei:em)
            return
                (
                    "*",
                    local:markdown($node/node(), $labels),
                    "*"
                )

            case element(tei:relation)
            return
                if ($node[exists((@active, @mutual, @passive))]) then
                    element {node-name($node)} {
                        $node/@*[not(local-name(.) = ('active', 'mutual', 'passive'))],
                        for $ref in tokenize($node/@active, " ")[. ne ""]
                        let $label := $labels/label[@ref eq $ref]/text/text()
                        return
                            <tei:active ref="{$ref}">{$label}</tei:active>
                        ,
                        for $ref in tokenize($node/@mutual, " ")[. ne ""]
                        let $label := $labels/label[@ref eq $ref]/text/text()
                        return
                            <tei:mutual ref="{$ref}">{$label}</tei:mutual>
                        ,
                        for $ref in tokenize($node/@passive, " ")[. ne ""]
                        let $label := $labels/label[@ref eq $ref]/text/text()
                        return
                            <tei:passive ref="{$ref}">{$label}</tei:passive>
                        ,
                        local:markdown($node/node(), $labels)
                    }

                else
                    local:passthru($node, $labels)

            case element()
            return
                local:passthru($node, $labels)

            default
            return
                local:markdown($node/node(), $labels)
};

(: Recurse through child nodes :)
declare function local:passthru($node as node()*, $labels as element(labels)?) as item()* {
    element {node-name($node)} {
        $node/@*,
        local:markdown($node/node(), $labels)
    }
};

(:~
 : Given the a node from a TEI document, we first extract the refs from all descendant tei:relation active, mutual, or passive attributes.
 : Secondly, for each ref we try and find a TEI document in the database whose tei:idno matches the ref,
 : if we find a document, we use it to generate a label for the ref.
 :
 : @param $node the TEI node to start resolving tei:relation from
 :
 : @return A labels element containing refs and their labels, e.g. <labels><label ref="https://jalit.org/person/34">Bahīya</label></labels>, or if there are no labels, then an empty sequence.
 :)
declare function local:get-labels($node as node()?) as element(labels)? {

    (: Get the relation refs from the the source TEI document - these are our lookup keys for later finding the labels :)
    let $refs as xs:string* :=
            distinct-values(
                    for $relation in $node//tei:relation[exists((@active, @mutual, @passive))]
                    let $active := tokenize($relation/@active[string-length(normalize-space(.)) gt 0]/string(), " ")
                    let $mutual := tokenize($relation/@mutual[string-length(normalize-space(.)) gt 0]/string(), " ")
                    let $passive := tokenize($relation/@passive[string-length(normalize-space(.)) gt 0]/string(), " ")
                    return
                        ($active, $mutual, $passive)[. ne ""]
            )
    return

        (: Now we try and find a label for each one of those refs in the database :)
        let $labels :=
                let $expanded-refs := $refs ! (., concat(., "/"), concat(., "/tei")) (:  Expand each ref to 3 possible refs :)
                let $collection := "/db/apps/majlis-data/data"
                let $id-nos := collection($collection)//tei:idno[@type eq "URI"][. = $expanded-refs]
                return

                    (: Iterate through the expanded-refs in sets of 3 :)
                    for $i in 1 to xs:integer(count($expanded-refs) div 3)
                    let $set-of-expanded-refs := ($expanded-refs[$i * 3 - 2], $expanded-refs[$i * 3 - 1], $expanded-refs[$i * 3])
                    return

                            if ($id-nos[. = $set-of-expanded-refs[1]])
                            then
                                <label ref="{$set-of-expanded-refs[1]}">
                                    <text>{$id-nos[. = $set-of-expanded-refs[1]]/ancestor::tei:TEI[1]/descendant::tei:title[1]/descendant-or-self::text()}</text>
                                </label>

                            else if ($id-nos[. = $set-of-expanded-refs[2]])
                            then
                                <label ref="{$set-of-expanded-refs[2]}">
                                    <text>{$id-nos[. = $set-of-expanded-refs[2]]/ancestor::tei:TEI[1]/descendant::tei:title[1]/descendant-or-self::text()}</text>
                                </label>

                            else if ($id-nos[. = $set-of-expanded-refs[3]])
                            then
                                <label ref="{$set-of-expanded-refs[3]}">
                                    <text>{$id-nos[. = $set-of-expanded-refs[3]]/ancestor::tei:TEI[1]/descendant::tei:title[1]/descendant-or-self::text()}</text>
                                </label>
                            else
                                () (: NOTE(AR) there is no label for this ref... that is okay as an @active, @mutual, or @passive attribute may contain multiple refs and some of those refs may be external to the database, and therefore we can't resolve them :)
        return
            if (exists($labels))
            then
                <labels>{$labels}</labels>
            else
                ()
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

    else
        request:get-data()
};


if ($local:github = "browse") then
    let $json := gitcommit:list-files()
    return
        response:stream($json, "method=TEXT media-type=application/json")
else
    let $data := local:get-data()
    let $labels := local:get-labels($data)
    return
        local:markdown($data, $labels)

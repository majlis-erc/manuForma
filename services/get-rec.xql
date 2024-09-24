xquery version "3.1";
(:~
 : Get data for TEI XForms
 : 
:)
import module namespace config="http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit="http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
import module namespace http="http://expath.org/ns/http-client";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";

(:element {fn:QName("http://www.w3.org/2013/XSL/json", "map")} { }:)
(: Recurse through child nodes :)
declare function local:markdown($nodes as node()*) as item()* { 
  for $node in $nodes
  return 
    typeswitch($node)
        case processing-instruction() return $node 
        case comment() return $node   
        case text() return normalize-space($node)
        case element(tei:TEI) return 
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
                {($node/@*, local:markdown($node/node()))}
            </TEI>
        case element(tei:p) return 
            if($node/parent::tei:quote or $node/parent::tei:summary or $node/parent::tei:note or $node/parent::tei:desc) then 
                (local:markdown($node/node()),'&#10;&#10;')
            else element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown($node/node()))}
        case element(tei:lb) return '&#10;'   
        case element(tei:em) return 
            ('*',local:markdown($node/node()),'*')
        case element(tei:relation) return 
            if($node[@mutual] or $node[@active] or $node[@passive]) then
                <relation xmlns="http://www.tei-c.org/ns/1.0">
                    {$node/@*[not(local-name() = 'mutual') and not(local-name() = 'active') and not(local-name() = 'passive')]}
                    {
                        let $active := 
                            if(contains($node/@active,' ')) then
                                for $a in tokenize($node/@active,' ')
                                return  
                                    <active xmlns="http://www.tei-c.org/ns/1.0">{$a}</active>
                            else 
                                <active xmlns="http://www.tei-c.org/ns/1.0">{string($node/@active)}</active>
                        let $passive := 
                            if(contains($node/@passive,' ')) then
                                for $p in tokenize($node/@passive,' ')
                                return  
                                    <passive xmlns="http://www.tei-c.org/ns/1.0">{$p}</passive>
                            else 
                                <passive xmlns="http://www.tei-c.org/ns/1.0">{string($node/@passive)}</passive>
                        let $mutual := 
                            if(contains($node/@mutual,' ')) then
                                for $m in tokenize($node/@mutual,' ')
                                return  
                                    <mutual xmlns="http://www.tei-c.org/ns/1.0">{$m}</mutual>
                            else 
                                <mutual xmlns="http://www.tei-c.org/ns/1.0">{string($node/@mutual)}</mutual>
                       return ($active,$passive,$mutual)
                        
                    }
                    {local:markdown($node/node())}
                </relation>
            else element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown($node/node()))}
        case element() return local:passthru($node)
        default return local:markdown($node/node())
};

(: Recurse through child nodes :)
declare function local:passthru($node as node()*) as item()* { 
    element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} 
    {($node/@*,local:markdown($node/node()))
    }
};


let $start := if(request:get-parameter('start','') != '') then request:get-parameter('start','') else '1'
let $searchURI := if(request:get-parameter('searchURI','') != '') then request:get-parameter('searchURI','') else 'http://localhost:8080/exist/apps/majlis/modules/content-negotiation/content-negotiation.xql?results=manuForma'
let $eXistCollection := if(request:get-parameter('eXistCollection','') != '') then request:get-parameter('eXistCollection','') else concat($config:app-root,'/data')
let $github-path := if(request:get-parameter('githubPath','') != '') then request:get-parameter('githubPath','') else 'data/tei/'
let $github-repo := if(request:get-parameter('githubRepo','') != '') then request:get-parameter('githubRepo','') else 'blogs'
let $github-owner := if(request:get-parameter('githubOwner','') != '') then request:get-parameter('githubOwner','') else 'wsalesky'
let $github-branch := if(request:get-parameter('githubBranch','') != '') then request:get-parameter('githubBranch','') else 'master'
let $data := 
    if(request:get-parameter('postdata','')) then 
        request:get-parameter('postdata','')
    else if(request:get-parameter('template','') = 'true') then
        if(request:get-parameter('path','') != '') then 
            if(contains(request:get-parameter('path',''),$config:app-root)) then 
                doc(request:get-parameter('path',''))
            else if(starts-with(request:get-parameter('path',''),'/db/')) then 
                doc(request:get-parameter('path',''))
            else doc($config:app-root || request:get-parameter('path',''))
        else ()
    else if(request:get-parameter('search','') = 'true') then
        if(request:get-parameter('view','') = 'all') then 
            <data>{
                for $r in collection($eXistCollection)//tei:TEI
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data>
        else if(request:get-parameter('q','') != '') then
            <data>{
                    let $facetparams := 
                        let $params := request:get-parameter-names()
                        for $f in $params
                        where starts-with($f, 'facet')
                        return 
                            ('&amp;' || $f || '=' || escape-uri(request:get-parameter($f,''),true()))
                    let $url := ($searchURI ||'&amp;q=' || escape-uri(request:get-parameter('q',''),true()) || '&amp;existCollection=' || $eXistCollection || '&amp;start=' || $start || ($facetparams))
                    let $hits := http:send-request(<http:request http-version="1.1" href="{xs:anyURI($url)}" method="get"/>)
                    return $hits
           }</data>
        else if(request:get-parameter('idno','') != '') then
            let $idno := if(starts-with(request:get-parameter('idno',''),'http')) then 
                            request:get-parameter('idno','')
                         else if(request:get-parameter('baseURI','') != '') then
                            concat(request:get-parameter('baseURI',''),request:get-parameter('idno',''))
                         else concat('/',request:get-parameter('idno',''))
            return 
                if($idno != '') then
                    <data idno="{$idno}">{
                        for $r in collection($eXistCollection)//tei:idno[. = $idno] | collection($eXistCollection)//tei:idno[. = ($idno || '/tei')] 
                        | collection($eXistCollection)//tei:idno[ends-with(.,$idno)] 
                        let $title := string($r/ancestor::tei:TEI/descendant::tei:title[1])
                        let $idno := $r
                        order by $title
                        return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
                    }</data>
                else <div>Empty idno</div>
        else  ()  
    else if(request:get-parameter('github','') = 'browse') then
        gitcommit:list-files()        
    else  request:get-data()    
return local:markdown($data)

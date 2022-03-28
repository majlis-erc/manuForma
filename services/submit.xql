xquery version "3.1";
(:~
 : Submit xforms generated data
 : @param $type options view (view xml in new window), download (download xml without saving), 
 : save (save to db, only available to logged in users)
:)
import module namespace config="http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit="http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
import module namespace http="http://expath.org/ns/http-client";

declare default element namespace "http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace httpclient="http://exist-db.org/xquery/httpclient";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace json = "http://www.json.org";

declare option output:method "xml";
declare option output:media-type "text/xml";

(: Any post processing to TEI form data happens here :)
declare function local:transform($nodes as node()*) as item()* {
  for $node in $nodes
  let $type := if($node/ancestor::tei:TEI/descendant::tei:body/tei:entryFree) then'keyword'  else 'place' 
  let $generateID := $node/ancestor::tei:TEI/descendant::tei:body/child::*[1]/tei:idno[@type='URI'][not(empty(.))][1]
  (:
  let $URI := if(starts-with($generateID, $config:base-uri)) then $generateID 
              else concat($config:base-uri,'/',$type,'/',$generateID)
   :) 
  let $URI := $generateID
  let $id := tokenize($URI,'/')[last()] 
  return 
    typeswitch($node)
        case processing-instruction() return $node 
        case comment() return $node 
        case text() return parse-xml-fragment($node)
        case element(tei:TEI) return 
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
                {($node/@*[. != ''], local:transform($node/node()))}
            </TEI>
        case element() return local:passthru($node)
        default return local:transform($node/node())
};

(: Recurse through child nodes :)
declare function local:passthru($node as node()*) as item()* { 
    element {local-name($node)} {($node/@*[. != ''], local:transform($node/node()))}
};

let $data := if(request:get-parameter('postdata','')) then request:get-parameter('postdata','') else request:get-data()
let $record := 
        if($data instance of node()) then
            $data//tei:TEI
        else fn:parse-xml($data) 
let $post-processed-xml := local:transform($record)    
let $uri := replace($post-processed-xml/descendant::tei:idno[1],'/tei','')
let $id := tokenize($uri,'/')[last()]
let $file-name := 
        if($id != '') then 
            concat($id, '.xml') 
        else 'form.xml'
let $collection-uri := concat($config:app-root,'/data')
let $github-path := if(request:get-parameter('githubPath','') != '') then request:get-parameter('githubPath','') else 'data/tei/'
let $github-repo := if(request:get-parameter('githubRepo','') != '') then request:get-parameter('githubRepo','') else 'blogs'
let $github-owner := if(request:get-parameter('githubOwner','') != '') then request:get-parameter('githubOwner','') else 'wsalesky'
let $github-branch := if(request:get-parameter('githubBranch','') != '') then request:get-parameter('githubBranch','') else 'master'
return 
        if(request:get-parameter('type', '') = 'save') then
            try {
                let $save := xmldb:store($collection-uri, xmldb:encode-uri($file-name), $post-processed-xml)
                return 
                 <response status="okay" code="200"><message>Record saved, thank you for your contribution. {$post-processed-xml}</message></response>  
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to update resource {$id}: {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }
        else if(request:get-parameter('type', '') = 'github') then
           try {
                let $save := gitcommit:run-commit($post-processed-xml, concat($github-path,$file-name), concat("User submitted content for ",$file-name))
                return
                 <response status="okay" code="200">
                    <message>Thank you for your contribution </message>
                 </response>  
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to submit, please download your changes and send via email. {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }         
        else if(request:get-parameter('type', '') = ('download','view')) then
                (response:set-header("Content-Type", "application/xml; charset=utf-8"),
                 response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml)     
        else if(request:get-parameter('type', '') = 'upload') then 
              (: (response:set-header("Content-Type", "text/xml; charset=utf-8"),
                response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml)
                :)
                <data>{$post-processed-xml}</data>
        else 
            <response code="500">
                <message>General Error</message>
            </response> 
xquery version "3.1";
(:~
 : Submit xforms generated data
 : @param $type options view (view xml in new window), download (download xml without saving), save (save to db, only available to logged in users)
:)
(:import module namespace config="http://srophe.org/srophe/config" at "../../modules/config.xqm";:)
(:import module namespace gitcommit="http://syriaca.org/srophe/gitcommit" at "git-commit.xql";:)
import module namespace http="http://expath.org/ns/http-client";

declare default element namespace "http://www.tei-c.org/ns/1.0";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace httpclient="http://exist-db.org/xquery/httpclient";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace json = "http://www.json.org";

declare option output:method "xml";
declare option output:media-type "text/xml";

declare variable $id {request:get-parameter('id', '')};
declare variable $type {request:get-parameter('type', '')};

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

<div>
{
let $data := if(request:get-parameter('postdata','')) then request:get-parameter('postdata','') else request:get-data()
let $record := 
    if($data instance of node()) then
        $data//tei:TEI
    else fn:parse-xml($data) 
let $post-processed-xml := local:transform($record)    
return $post-processed-xml
    }
</div>

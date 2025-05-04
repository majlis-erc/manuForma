xquery version "3.0";
(:~
 : Get data for TEI XForms
 : 
:)
import module namespace config="http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit="http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";

(: Any post processing to TEI form data happens here :)
declare function local:transform($nodes as node()*) as item()* {
  for $node in $nodes
  let $type := if($node/ancestor::tei:TEI/descendant::tei:body/tei:entryFree) then'keyword'  else 'place' 
  let $generateID := $node/ancestor::tei:TEI/descendant::tei:body/child::*[1]/tei:idno[@type='URI'][not(empty(.))][1]
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
let $xml-as-string := util:base64-decode($data)
let $parsed-xml := fn:parse-xml($xml-as-string)
let $record := 
        if($parsed-xml instance of node()) then
            $parsed-xml//tei:TEI
        else fn:parse-xml($parsed-xml) 
let $post-processed-xml := local:transform($record)     
return ($parsed-xml)
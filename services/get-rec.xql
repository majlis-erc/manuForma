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

let $data := 
    if(request:get-parameter('postdata','')) then 
        request:get-parameter('postdata','')
    else if(request:get-parameter('template','') = 'true') then
        if(request:get-parameter('path','') != '') then 
            if(contains(request:get-parameter('path',''),$config:app-root)) then 
                doc(request:get-parameter('path',''))
            else doc($config:app-root || request:get-parameter('path',''))
        else 'Working on this'        
    else if(request:get-parameter('search','') = 'true') then
        if(request:get-parameter('view','') = 'all') then 
            <data>{
                for $r in collection($config:app-root || '/data')//tei:TEI
                return <record src="{document-uri(root($r))}" name="{string($r/descendant::tei:title[1])}"/>
            }</data>
        else if(request:get-parameter('q','') != '') then
            <data>{
                for $r in collection($config:app-root || '/data')//tei:TEI[descendant::tei:teiHeader[ft:query(.,request:get-parameter('q',''))]]
                return <record src="{document-uri(root($r))}" name="{string($r/descendant::tei:title[1])}"/>
            }</data>
        else 'Working on this, search'
    else if(request:get-parameter('github','') = 'browse') then
        gitcommit:list-files()        
    else  request:get-data()    
return $data

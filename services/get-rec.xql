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
    else if(request:get-parameter('eXistCollection','') != '') then
        if(request:get-parameter('view','') = 'all') then
            <data>{
                for $r in collection(request:get-parameter('eXistCollection',''))//tei:TEI
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data>
        else if(request:get-parameter('q','') != '') then
            <data>{
                for $r in collection(request:get-parameter('eXistCollection',''))//tei:TEI[descendant::tei:teiHeader[ft:query(.,request:get-parameter('q',''))] or descendant::tei:body[ft:query(.,request:get-parameter('q',''))]]
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data> 
        else ()    
    else if(request:get-parameter('search','') = 'true') then
        if(request:get-parameter('view','') = 'all') then 
            <data>{
                for $r in collection($config:app-root || '/data')//tei:TEI
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data>
        else if(request:get-parameter('q','') != '') then
            <data>{
                for $r in collection($config:app-root || '/data')//tei:TEI[descendant::tei:teiHeader[ft:query(.,request:get-parameter('q',''))]]
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data>
        else ()
    else if(request:get-parameter('github','') = 'browse') then
        gitcommit:list-files()        
    else  request:get-data()    
return $data

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

(:
http://localhost:8080/exist/apps/manuForma/services/get-rec.xql?template=true&path=/db/apps/majlis-data/data/manuscripts/tei/LONBLOR2494.xml
:)
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
                for $r in collection($eXistCollection)//tei:TEI[descendant::tei:teiHeader[ft:query(.,request:get-parameter('q',''))]]
                let $title := string($r/descendant::tei:title[1])
                let $idno := string($r/descendant::tei:publicationStmt[1]/tei:idno[@type='URI'][1])
                order by $title
                return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
            }</data>
        else if(request:get-parameter('idno','') != '') then
            let $idno := if(starts-with(request:get-parameter('idno',''),'http')) then 
                            request:get-parameter('idno','')
                         else if(request:get-parameter('baseURI','') != '') then
                            concat(request:get-parameter('baseURI',''),request:get-parameter('idno',''))
                         else ()
            return 
                if($idno != '') then
                    <data idno="{$idno}">{
                        for $r in collection($eXistCollection)//tei:idno[. = $idno] | collection($eXistCollection)//tei:idno[. = ($idno || '/tei')] 
                        let $title := string($r/ancestor::tei:TEI/descendant::tei:title[1])
                        let $idno := $r
                        order by $title
                        return <record src="{document-uri(root($r))}" name="{$title}" idno="{concat('[',$idno,']')}"/>
                    }</data>
                else ()
        else  ()  
    else if(request:get-parameter('github','') = 'browse') then
        gitcommit:list-files()        
    else  request:get-data()    
return $data

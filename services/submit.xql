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
declare option output:omit-xml-declaration "no";

(: Any post processing to TEI form data happens here :)
declare function local:transform($nodes as node()*) as item()* {
  for $node in $nodes
  let $type := if($node/ancestor::tei:TEI/descendant::tei:body/tei:entryFree) then'keyword'  else 'place' 
  let $generateID := replace($node/ancestor::tei:TEI/descendant::tei:publicationStmt/tei:idno[@type='URI'][not(empty(.))][1],'/tei','')
  (:
  let $URI := if(starts-with($generateID, $config:base-uri)) then $generateID 
              else concat($config:base-uri,'/',$type,'/',$generateID)
   :) 
   (:
  let $userInfo := doc(concat($config:nav-base,'/userInfo'))
  let $user := $userInfo//*:user
  element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('name',$id,'-',
                        count($node/preceding-sibling::*[local-name(.) = 'term']) + 1) },
                        if($node/@source[. != '']) then 
                            attribute source { concat('#bibl',$id,'-', $node/@source)}
                        else (),
                        local:transform($node/node())
                    }
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
        case element(tei:ab) return
            if($node[@type='factoid'][@subtype='relation']) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('factoid-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    }
            else local:passthru($node)
        case element(tei:idno) return
            if($node/parent::tei:ab[@type='factoid'][@subtype='relation']) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:idno) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    }
            else local:passthru($node)  
            (: 
             attribute xml:id { concat($id, generate-id($node) )},
            /ab/bibl/ptr/@target="{Filenumber}" WS: NOTE not done
         case element(tei:ptr) return
            if($node[parent::tei:bibl][ancestor::tei:ab[@type='factoid'][@subtype='relation']]) then
                
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'target') and not(name(.) = 'source')],
                        attribute xml:id { concat($id, generate-id($node) )},
                        local:passthru($node)
                    }
            else local:passthru($node)
            :)
        case element(tei:place) return
            if($node[parent::tei:listPlace]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('place-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)             
        case element(tei:placeName) return
            if($node[parent::tei:place/parent::tei:listPlace]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:placeName) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:bibl) return
            if($node[parent::tei:place/parent::tei:listPlace] or $node[parent::tei:person/parent::tei:listPerson or parent::tei:note/parent::tei:bibl/parent::tei:body] or $node[parent::tei:bibl/parent::tei:bibl/parent::tei:body]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('bibl-',count($node/preceding-sibling::tei:bibl) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else if($node[parent::tei:body/parent::tei:text]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('work-',$id)},
                        for $n in $node/node()
                        return local:transform($n)
                    }  
            else if($node[parent::tei:listBibl/parent::tei:additional/parent::tei:msDesc]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('bibl-',
                        (count($node/parent::tei:listBibl/parent::tei:additional/preceding-sibling::tei:additional) + 1),
                        (count($node/parent::tei:listBibl/preceding-sibling::tei:listBibl) + 1),
                        (count($node/preceding-sibling::tei:bibl) + 1 ))
                        },
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)        
        case element(tei:title) return
            if($node[parent::tei:bibl/parent::tei:body]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('title-',count($node/preceding-sibling::tei:title) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:person) return
            if($node[parent::tei:listPerson]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('person-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node) 
        case element(tei:persName) return
            if($node[parent::tei:person/parent::tei:listPerson]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:persName) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:msDesc) return
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('ms-',$id)},
                        for $n in $node/node()
                        return local:transform($n)
                    }
        case element(tei:msItem) return
            if($node[parent::tei:msContents/parent::tei:msDesc]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('item-',(count($node/parent::tei:msContents/preceding-sibling::tei:msContents) + 1),
                        (count($node/preceding-sibling::tei:msItem) + 1 ))},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)  
        case element(tei:layout) return
            if($node[parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/parent::tei:msDesc]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('layout-',
                        (count($node/parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1),
                        (count($node/parent::tei:layoutDesc/parent::tei:objectDesc/preceding-sibling::tei:objectDesc) + 1),
                        (count($node/parent::tei:layoutDesc/preceding-sibling::tei:layoutDesc) + 1),
                        (count($node/preceding-sibling::tei:layout) + 1 ))},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:handNote) return
            if($node[parent::tei:handDesc/parent::tei:physDesc/parent::tei:msDesc]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('hand-',
                        (count($node/parent::tei:handDesc/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1),
                        (count($node/parent::tei:handDesc/preceding-sibling::tei:handDesc) + 1),
                        (count($node/preceding-sibling::tei:handNote) + 1 ))},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)   
        case element(tei:item) return
            if($node[parent::tei:list/parent::tei:additions/parent::tei:physDesc/parent::tei:msDesc]) then
                element { local-name($node) } 
                    {   $node/@*[. != '' and not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        attribute xml:id { concat('add-',
                        (count($node/parent::tei:list/parent::tei:additions/parent::tei:physDesc/preceding-sibling::tei:physDesc) + 1),
                        (count($node/parent::tei:list/parent::tei:additions/preceding-sibling::tei:additions) + 1),
                        (count($node/parent::tei:list/preceding-sibling::tei:list) + 1),
                        (count($node/preceding-sibling::tei:item) + 1 ))},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node) 
        (:   

        case element(tei:revisionDesc) return 
            <revisionDesc xmlns="http://www.tei-c.org/ns/1.0">
                {($node/@*[. != ''], local:transform($node/node()))}
                <change when="{current-dateTime()}" who="#{string($user)}" test="{concat($config:nav-base,'/userInfo')}">XForms Editing by {string($user)}</change>
            </revisionDesc>   
         :)   
        case element() return local:passthru($node)
        default return local:transform($node/node())
};

(: 
add change element? revisionDesc/change 
ex: <change n="1.0" when="2018-03-21-04:00" who="#TGM">CREATED: record</change>
:)
(: Recurse through child nodes :)
declare function local:passthru($node as node()*) as item()* { 
    element {local-name($node)} {($node/@*[. != ''], local:transform($node/node()))}
};

let $data := if(request:get-parameter('postdata','')) then request:get-parameter('postdata','') else request:get-data()
let $record := 
        if($data instance of node()) then
            $data//tei:TEI
        else parse-xml-fragment($data) 
let $post-processed-xml := local:transform($record)    
let $uri := replace($post-processed-xml/descendant::tei:idno[1],'/tei','')
let $id := tokenize($uri,'/')[last()]
let $file-name := 
        if($id != '') then 
            concat($id, '.xml') 
        else 'form.xml'
let $eXistCollection := if(request:get-parameter('eXistCollection','') != '') then request:get-parameter('eXistCollection','') else concat($config:app-root,'/data')
let $github-path := if(request:get-parameter('githubPath','') != '') then request:get-parameter('githubPath','') else 'data/tei/'
let $github-repo := if(request:get-parameter('githubRepo','') != '') then request:get-parameter('githubRepo','') else 'blogs'
let $github-owner := if(request:get-parameter('githubOwner','') != '') then request:get-parameter('githubOwner','') else 'wsalesky'
let $github-branch := if(request:get-parameter('githubBranch','') != '') then request:get-parameter('githubBranch','') else 'master'
return 
    if(request:get-parameter('type', '') = 'save') then
            try {
                let $save := xmldb:store($eXistCollection, xmldb:encode-uri($file-name), $post-processed-xml)
                return 
                 <response status="okay" code="200"><message>{$save} Record {$id} saved, thank you for your contribution. </message></response>  
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
                    <message>Record saved to the {$github-repo} GitHub. Thank you for your contribution. {$save}</message>
                 </response>  
            } catch * {
                (response:set-status-code( 500 ),
                <response status="fail">
                    <message>Failed to submit, please download your changes and send via email. {concat($err:code, ": ", $err:description)}</message>
                </response>)
            }             
        else if(request:get-parameter('type', '') = 'download') then
                (response:set-header("Content-Type", "application/xml; charset=utf-8"),
                 response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml)  
        else if(request:get-parameter('type', '') = 'view') then
                (response:set-header("Content-Type", "application/xml; charset=utf-8"),
                 (:response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml):)
                 $post-processed-xml
                 (:<div>Hello? View XML here</div>:)
                 )
        else if(request:get-parameter('type', '') = 'previewHTML') then 
                  (response:set-header("Content-Type", "text/html; charset=utf-8"),
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
                                <div class="record">{
                                    transform:transform($post-processed-xml, doc('/db/apps/majlis/resources/xsl/tei2html.xsl'), 
                                    <parameters>
                                        <param name="data-root" value="'/db/apps/majlis-data/data'"/>
                                        <param name="app-root" value="'/db/apps/majlis'"/>
                                        <param name="nav-base" value="'majlis'"/>
                                        <param name="base-uri" value="https://jalit.org"/>
                                    </parameters>
                                    )}
                                </div>
                            </body>
                            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/js/jquery.min.js">&#160;</script>
                                <script type="text/javascript" src="/exist/rest/apps/majlis/resources/jquery-ui/jquery-ui.min.js">&#160;</script>
                                <script type="text/javascript" src="/exist/rest/apps/majlis/resources/bootstrap/js/bootstrap.min.js">&#160;</script>
                        </html>
                        )
        else if(request:get-parameter('type', '') = 'upload') then 
              (: (response:set-header("Content-Type", "text/xml; charset=utf-8"),
                response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml)
                :)
                <data>{$post-processed-xml}</data>
        else 
            <response code="500">
                <message>General Error</message>
            </response> 
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

declare function local:createID(){
    let $eXistCollection := if(request:get-parameter('eXistCollection','') != '') then request:get-parameter('eXistCollection','') else concat($config:app-root,'/data')
    let $newID :=
        for $r in collection($eXistCollection)
        let $id := tokenize($r/descendant::tei:publicationStmt/tei:idno[@type='URI'][1],'/')[last()]
        let $num := if($id castable as xs:integer) then xs:integer($id) else 0
        order by $num 
        return $num
    let $baseURI := 
        if(contains($eXistCollection, '/manuscripts/')) then
            'https://jalit.org/manuscript/'
        else if(contains($eXistCollection, '/persons/')) then
            'https://jalit.org/person/'
        else if(contains($eXistCollection,'/works/')) then
            'https://jalit.org/work/'
        else if(contains($eXistCollection, '/places/')) then
            'https://jalit.org/place/'
        else if(contains($eXistCollection, '/relations/')) then
            'https://jalit.org/relation/'                
        else 'https://jalit.org/'
    return concat($baseURI,$newID[last()]  + 1)
};

(: Any post processing to TEI form data happens here :)
declare function local:transform($nodes as node()*) as item()* {
  for $node in $nodes
  let $new := request:get-parameter('new','')
  let $URI := 
    if($new = 'true') then 
        local:createID() 
    else ()
  let $id := 
    if($new = 'true') then tokenize($URI,'/')[last()] 
    else tokenize($node/ancestor-or-self::tei:TEI/descendant::tei:publicationStmt/tei:idno[@type='URI'][1],'/')[last()]
  return 
    typeswitch($node)
        case processing-instruction() return $node 
        case comment() return $node 
        case text() return (:parse-xml-fragment($node):) $node
        case element(tei:TEI) return 
            <TEI xmlns="http://www.tei-c.org/ns/1.0">
                {($node/@*[not(name(.) = 'class')], local:transform($node/node()))}
            </TEI>
        case element(tei:desc) return 
            element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown2TEI($node/node()))}
        case element(tei:note) return 
            element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown2TEI($node/node()))}
        case element(tei:summary) return 
           element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown2TEI($node/node()))}
        case element(tei:quote) return 
            element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown2TEI($node/node()))}
        case element(tei:p) return 
            element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, local:markdown2TEI($node/node()))}               
        case element(tei:ab) return
            if($node[@type='factoid'][@subtype='relation']) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('factoid-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    }
            else local:passthru($node)
        case element(tei:editor) return
            if($node/descendant-or-self::text() = '') then ()
            else local:passthru($node) 
        case element(tei:idno) return
            if($node/parent::tei:ab[@type='factoid'][@subtype='relation']) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:idno) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    }
            else if(($new = 'true') and $node/parent::tei:publicationStmt) then                     
                    element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} {($node/@*, $URI)}
            else local:passthru($node)  
        case element(tei:place) return
            if($node[parent::tei:listPlace]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute xml:id {concat('#',$node/@source)}
                        else (),
                        attribute xml:id { concat('place-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)             
        case element(tei:placeName) return
            if($node[parent::tei:place/parent::tei:listPlace]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:placeName) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:bibl) return
            if($node[parent::tei:place/parent::tei:listPlace] or $node[parent::tei:person/parent::tei:listPerson or parent::tei:note/parent::tei:bibl/parent::tei:body] or $node[parent::tei:bibl/parent::tei:bibl/parent::tei:body]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'source')],
                        (:attribute xml:id { concat('bibl-',count($node/preceding-sibling::tei:bibl) + 1 )},:)
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else if($node[parent::tei:body/parent::tei:text]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'source')],
                        (:attribute xml:id { concat('work-',$id)},:)
                        for $n in $node/node()
                        return local:transform($n)
                    }  
            else if($node[parent::tei:listBibl/parent::tei:additional/parent::tei:msDesc]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'source')],
                        (:attribute xml:id { concat('bibl-',
                        (count($node/parent::tei:listBibl/parent::tei:additional/preceding-sibling::tei:additional) + 1),
                        (count($node/parent::tei:listBibl/preceding-sibling::tei:listBibl) + 1),
                        (count($node/preceding-sibling::tei:bibl) + 1 ))
                        },:)
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)        
        case element(tei:title) return
            if($node[parent::tei:bibl/parent::tei:body]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute xml:id {concat('#',$node/@source)}
                        else (),
                        attribute xml:id { concat('title-',count($node/preceding-sibling::tei:title) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:person) return
            if($node[parent::tei:listPerson]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('person-',$id )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node) 
        case element(tei:persName) return
            if($node[parent::tei:person/parent::tei:listPerson]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('name-',count($node/preceding-sibling::tei:persName) + 1 )},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)
        case element(tei:msDesc) return
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('ms-',$id)},
                        for $n in $node/node()
                        return local:transform($n)
                    }
        case element(tei:msItem) return
            if($node[parent::tei:msContents/parent::tei:msDesc]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
                        attribute xml:id { concat('item-',(count($node/parent::tei:msContents/preceding-sibling::tei:msContents) + 1),
                        (count($node/preceding-sibling::tei:msItem) + 1 ))},
                        for $n in $node/node()
                        return local:transform($n)
                    } 
            else local:passthru($node)  
        case element(tei:layout) return
            if($node[parent::tei:layoutDesc/parent::tei:objectDesc/parent::tei:physDesc/parent::tei:msDesc]) then
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
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
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
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
                element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node)) } 
                    {   $node/@*[not(name(.) = 'xml:id') and not(name(.) = 'source')],
                        if($node[@source != '']) then
                            attribute source {concat('#',substring-after($node/@source,'#'))}
                        else (),
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
         case element(tei:relation) return 
            if($node/tei:mutual or $node/tei:active or $node/tei:passive)  then
                let $passiveString := string-join($node/tei:passive/@ref,' ') 
                let $activeString := string-join($node/tei:active/@ref,' ')
                let $mutualString := string-join($node/tei:mutual/@ref,' ')
                return 
                    <relation xmlns="http://www.tei-c.org/ns/1.0">
                        {$node/@*[not(local-name() = 'mutual') and not(local-name() = 'active') and not(local-name() = 'passive')],
                         attribute active {$activeString},
                         attribute passive {$passiveString},
                         attribute mutual {$mutualString}
                        }
                    </relation>
            else local:passthru($node)
        case element() return local:passthru($node)
        default return local:transform($node/node())
};


(: Recurse through child nodes :)
declare function local:passthru($node as node()*) as item()* { 
    element {fn:QName("http://www.tei-c.org/ns/1.0",local-name($node))} 
    {($node/@*[not(name(.) = 'source')],
        if($node[@source != '']) then
            attribute source {concat('#',substring-after($node/@source,'#'))}
        else (),
    local:transform($node/node()))
    }
};

(: Markdown to TEI :)
declare function local:markdown2TEI($node){
    for $l in tokenize($node, '\n\n')
    return 
    (: edit for 639 rollback is <p>{local:lineBreak($l)}</p> :)
        if(local:lineBreak($l) = '') then () 
        else <p>{local:lineBreak($l)}</p>
};
    
declare function local:lineBreak($s){
   for $node in fn:analyze-string($s, "(.*?)\n")/child::*
   return 
       typeswitch($node)
        case element(fn:match) return (local:markdown($node),<lb/>)
        default return local:markdown($node/node())
};

declare function local:markdown($s){
   for $node in fn:analyze-string($s, "\*(.*?)\*")/child::*
   return 
       typeswitch($node)
        case element(fn:match) return <em>{$node/fn:group/node()}</em>
        default return $node/node()
   
};  

let $data := if(request:get-parameter('postdata','')) then request:get-parameter('postdata','') else request:get-data()
let $record := $data
        (:if($data instance of node()) then
            $data/node()
        else parse-xml-fragment($data):)
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
                let $saveDB := xmldb:store($eXistCollection, xmldb:encode-uri($file-name), $post-processed-xml)
                return
                 (<response status="okay" code="200">
                    <message>Record saved to the {$github-repo} GitHub. Thank you for your contribution. {xmldb:store($eXistCollection, xmldb:encode-uri($file-name), $post-processed-xml)}</message>
                    <existURL>{$saveDB}</existURL>
                    <url>{$save}</url>
                 </response>
                 )
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
                 )
        else if(request:get-parameter('type', '') = 'previewHTML') then 
                let $response := 
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
                return response:stream($response, 'method=html media-type=text/html')        
        else if(request:get-parameter('type', '') = 'upload') then 
              (: (response:set-header("Content-Type", "text/xml; charset=utf-8"),
                response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),$post-processed-xml)
                :)
                <data>{$post-processed-xml}</data>
        else 
            <response code="500">
                <message>General Error</message>
            </response> 
xquery version "3.1";
(:~
 : Submit XForms generated data.
 :
 : HTTP Request Parameters:
 : @request-parameter eXistCollection The db path to the data collection
 : @request-parameter type The type of action to perform: <dl>
       <dt>save</dt>          <dd>Save to db. Only available to logged in users</dd>
       <dt>github</dt>        <dd>Commit to git and save to db. Only available to logged in users</dd>
       <dt>download</dt>      <dd>Download xml without saving</dd>
       <dt>view</dt>          <dd>View XML in new window</dd>
       <dt>previewHTML</dt>   <dd>View HTML preview</dd>
       <dt>upload</dt>        <dd>View the processed XML</dd>
 </dl>
 : @request-parameter new true if this is a new record, or false if editing an existing record
 : @request-parameter postdata the form data, if absent then the body of the request will be used
 : @request-parameter githubPath the path within the git repo to commit to
 : @request-parameter githubRepo the name of the GitHub repo
 :)
import module namespace config = "http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace gitcommit = "http://syriaca.org/srophe/gitcommit" at "git-commit.xql";
import module namespace rh = "http://localhost/manuForma/request-helper" at "../modules/request-helper.xqm";

import module namespace request = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

declare option output:method "xml";
declare option output:media-type "application/xml";
declare option output:omit-xml-declaration "no";
declare option output:indent "yes";

declare variable $local:exist-collection-path as xs:string := rh:request-param('eXistCollection', concat($config:app-root, '/data'));
declare variable $local:type as xs:string? := rh:request-param('type');
declare variable $local:new as xs:boolean := rh:request-param-bool("new");
declare variable $local:data := rh:request-param('postdata', request:get-data());
declare variable $local:github-path as xs:string := rh:request-param('githubPath', 'data/tei/');
declare variable $local:github-repo as xs:string := rh:request-param('githubRepo', 'blogs');

declare variable $local:user-id as xs:string := (request:get-attribute("org.exist.login.user"), sm:id()/sm:id/sm:real/sm:username/string(.))[1];
declare variable $local:user-name as xs:string := sm:get-account-metadata($local:user-id, xs:anyURI('http://axschema.org/namePerson'));

declare function local:extract-id-from-uri($uri as xs:string) as xs:integer {
    let $part := tokenize($uri, '/')[last()]
    return
        if ($part castable as xs:integer)
        then
            xs:integer($part)
        else
            0
};

declare function local:create-id() as xs:string {
    let $base-uri := 
            if (contains($local:exist-collection-path, "/manuscripts/")) then
                "https://jalit.org/manuscript/"
            else if (contains($local:exist-collection-path, "/persons/")) then
                "https://jalit.org/person/"
            else if (contains($local:exist-collection-path, "/works/")) then
                "https://jalit.org/work/"
            else if (contains($local:exist-collection-path, "/places/")) then
                "https://jalit.org/place/"
            else if (contains($local:exist-collection-path, "/relations/")) then
                "https://jalit.org/relation/"                
            else
                "https://jalit.org/"
    let $last-id := max(
        collection($local:exist-collection-path)//tei:idno[@type eq 'URI'][parent::tei:publicationStmt]/local:extract-id-from-uri(.)
    )
    let $new-id := $last-id + 1
    return
        concat($base-uri, $new-id)
}; 

declare function local:save($id as xs:string?, $file-name as xs:string, $post-processed-xml) as element(response) {
    try {
        let $save := xmldb:store($local:exist-collection-path, xmldb:encode-uri($file-name), $post-processed-xml)
        return 
            <response status="okay" code="200">
                <message>{$save} Record {$id} saved, thank you for your contribution.</message>
            </response>  
    } catch * {
        let $_ := util:log("ERROR", concat("Failed to update resource: ", $id, ". [", $err:line-number, ":", $err:column-number, "]", $err:module, ": ", $err:code, " ", $err:description))
        return
          <response status="fail" code="500">
              <message>Failed to update resource: {$id}. {concat($err:code, ": ", $err:description)}</message>
          </response>
    }
};

declare function local:git-commit($file-name as xs:string, $post-processed-xml) as element(response) {
    try {
        let $save := gitcommit:run-commit($post-processed-xml, concat($local:github-path, $file-name), concat("User submitted content for ", $file-name))
        let $save-db := xmldb:store($local:exist-collection-path, xmldb:encode-uri($file-name), $post-processed-xml)
        return
            <response status="okay" code="200">
                <message>Record saved to the {$local:github-repo} GitHub. Thank you for your contribution.</message>
                <existURL>{$save-db}</existURL>
                <url>{$save}</url>
            </response>
    } catch * {
        let $_ := util:log("ERROR", concat("Failed to submit, please download your changes and send via email. [", $err:line-number, ":", $err:column-number, "]", $err:module, ": ", $err:code, " ", $err:description))
        return
            <response status="fail" code="500">
                <message>Failed to submit, please download your changes and send via email. {concat($err:code, ": ", $err:description)}</message>
            </response>
    }  
};

declare function local:preview-html($post-processed-xml) as element(response) {
    <response status="okay" code="200" type="html">
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
                <div class="record">
                {
                  transform(map {
                          "source-node": $post-processed-xml,
                          "stylesheet-node": doc('/db/apps/majlis/resources/xsl/tei2html.xsl'),
                          "stylesheet-params": map {
                              "data-root": "/db/apps/majlis-data/data",
                              "app-root": "/db/apps/majlis",
                              "nav-base": "majlis",
                              "base-uri": "https://jalit.org"
                          }
                  })
                }
                </div>
            </body>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/js/jquery.min.js">&#160;</script>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/jquery-ui/jquery-ui.min.js">&#160;</script>
            <script type="text/javascript" src="/exist/rest/apps/majlis/resources/bootstrap/js/bootstrap.min.js">&#160;</script>
        </html>
    </response>
};


let $uri as xs:string? := 
        if ($local:new) then 
            local:create-id() 
        else ()
let $id as xs:string? :=
        if ($local:new) then
            tokenize($uri, "/")[last()][. ne ""]
        else
            tokenize($local:data//tei:idno[parent::tei:publicationStmt][@type eq "URI"][1], "/")[last()]

let $post-processed-xml := fn:transform(map {
        "stylesheet-node": doc("/db/apps/manuForma/services/manuforma-form-to-tei.xslt"),
        "source-node": $local:data,
        "stylesheet-params": map {
                xs:QName('new'): $local:new,
                xs:QName('id'): $id,
                xs:QName('uri'): $uri,
                xs:QName('user-id'): $local:user-id,
                xs:QName('user-name'): $local:user-name
        }
})?output
return

    let $uri as xs:string := replace($post-processed-xml/descendant::tei:idno[1], "/tei", "")
    let $id as xs:string? := (tokenize($uri, "/")[last()])[. ne ""]
    let $file-name as xs:string := 
            if ($id) then
                concat($id, ".xml")
            else
                "form.xml"
    return
        
        (: Route and process the request based on the 'type' parameter :)
        let $response :=
          switch ($local:type)
            case "save" return local:save($id, $file-name, $post-processed-xml)
            case "github" return local:git-commit($file-name, $post-processed-xml)
            case "download" return (
                    response:set-header("Content-Type", "application/xml; charset=utf-8"),
                    response:set-header("Content-Disposition", fn:concat("attachment; filename=", $file-name)),
                    $post-processed-xml
            )
            case "view" return (
                    response:set-header("Content-Type", "application/xml; charset=utf-8"),
                    $post-processed-xml
            )
            case "previewHTML" return local:preview-html($post-processed-xml)
            case "upload" return <data>{$post-processed-xml}</data>
            default return <response status="fail" code="400"><message>Bad request, type parameter missing</message></response>
        return
            (
                if ($response/@code)
                then
                    response:set-status-code(xs:integer($response/@code))
                else ()
                ,
                if ($response/@type = "html")
                then
                    response:stream($response/xhtml:html, "method=html media-type=text/html")
                else
                  $response
            )

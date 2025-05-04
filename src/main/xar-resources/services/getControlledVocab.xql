xquery version "3.0";

(:~
 : NOTE: Handle all lookups for controlled vocab. change name
 : Build dropdown list of available resources for citation
:)
declare namespace request="http://exist-db.org/xquery/request";
import module namespace http="http://expath.org/ns/http-client";

(:forms:build-instance($id):)
declare variable $id {request:get-parameter('id', '')};
declare variable $q {request:get-parameter('q', '')};
declare variable $idno {request:get-parameter('idno', '')};
declare variable $element {request:get-parameter('element', 'person')};
declare variable $action {request:get-parameter('action', '')};
declare variable $type {request:get-parameter('type', '')};
declare variable $api {request:get-parameter('apiURL', '')};
declare variable $format {request:get-parameter('format', '')};

(:
if(request:get-parameter('apiURL', '') != '') then
    <div>{request:get-parameter('apiURL', '')}</div>
else <div>Everything else</div>
:)
let $requestURL := $api
let $request := http:send-request(<http:request http-version="1.1" href="{xs:anyURI(concat($requestURL,'?q=',$q,'&amp;format=',$format))}" method="get"/>)
return 
    <div>{$request}</div>
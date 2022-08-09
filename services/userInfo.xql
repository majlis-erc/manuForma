xquery version "3.0";
(:~
 : Log users into forms, if not alread logged into admin module. 
:)
import module namespace config="http://localhost/manuForma/config" at "../modules/config.xqm";
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace functx="http://www.functx.com";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace request="http://exist-db.org/xquery/request";
declare option exist:serialize "method=xml media-type=text/xml indent=yes";

let $user := 
    if(request:get-attribute(concat($config:login-domain, '.user'))) then 
        request:get-attribute(concat($config:login-domain, '.user'))
    else 'no user'    
return 
    <response>
        <user>{$user}</user>
    </response>
(:
(login:set-user($config:login-domain, (), true()),
    if(request:get-parameter('user', '') != '') then
        <response><user>{$user}</user><password/></response>
    else if(request:get-parameter('logout', ()) = true()) then 
        <response><user></user><password/></response>          
    else  <response><user>{$user}</user><password/></response>)
:)
xquery version "3.0";

(: For user management :)
import module namespace login="http://exist-db.org/xquery/login" at "resource:org/exist/xquery/modules/persistentlogin/login.xql";
import module namespace sm = "http://exist-db.org/xquery/securitymanager";
import module namespace config="http://localhost/manuForma/config" at "modules/config.xqm";

declare variable $exist:path external;
declare variable $exist:resource external;
declare variable $exist:controller external;
declare variable $exist:prefix external;
declare variable $exist:root external;

(:Variables for login module. :)
declare variable $nav-base := $config:nav-base;
(:
declare variable $userParam := request:get-parameter("user", ());
declare variable $logout := request:get-parameter("logout", ());
:)

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
(: Log users in or out :)
else if ($exist:resource = "login") then 
    (
    login:set-user("org.exist.login", (), true()),
    let $user := request:get-attribute("org.exist.login.user")
    let $userParam := request:get-parameter("user","")
    let $logout := request:get-parameter("logout",())
    (:let $user := if(request:get-parameter("user", ()) != '') then request:get-parameter("user", ()) else request:get-attribute("org.exist.login.user"):)
    return
         try {
                if($user and sm:list-users() = $user) then 
                        <response status="success" message="Logged in">
                            <message><div>Logged in as {$user}</div></message>
                        </response>
                else if($userParam and sm:list-users() = $userParam) then
                        <response status="success" message="Logged in">
                            <message><div>Logged in as {$userParam}</div></message>
                        </response>                       
                else if($logout = 'true') then 
                        <response status="success" message="Logged out">
                            <message><div>You have been logged out. </div></message>
                        </response>
                 else (
                    (response:set-status-code( 500 ), 
                        <response status="fail" message="Wrong user or password user: {$user} userParam: {$userParam}">
                            <message><div>Wrong user or password user: {$user} userParam: {$userParam}</div></message>
                        </response>)
                 )
         } catch * {
            (response:set-status-code( 500 ), 
             <response status="fail" message="Wrong user or password user: {$user} userParam: {$userParam}">
                <message>{$err:description}</message>
             </response>)
         }
         )
(:
    (util:declare-option("exist:serialize", "method=json media-type=application/json"),
    try {
        let $loggedIn := login:set-user($config:login-domain, (), true())
        let $user := request:get-attribute($config:login-domain || ".user")
        return
           if ($user and sm:list-users() = $user) then
                <response>
                    <user>{$user}</user>
                    <logged>{$loggedIn}</logged>
                </response>
            else if($userParam and sm:list-users() = $userParam) then
                <response>
                    <user>{$user}</user>
                    <logged>{$loggedIn}</logged>
                </response>
            else if($logout = 'true') then 
               <response>
                    <success>You have been logged out.</success>
                </response> 
            else (
                <response>
                    <fail>Wrong user or password user: {$user} userParam: {$userParam}</fail>
                </response>
            )
    } catch * {
        <response>
            <fail>{$err:description}</fail>
        </response>
    })
    
:)    
(: Check user credentials :)
else if ($exist:resource = "userInfo") then 
    ((:util:declare-option("exist:serialize", "method=json media-type=application/json"),:)
     let $currentUser := 
                if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
                else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)
    let $group :=  
                if($currentUser) then 
                    sm:get-user-groups($currentUser) 
                else () 
    return
        (response:set-status-code( 200 ), 
            response:set-header("Content-Type", "text/xml"),
            <response status="success" xmlns="http://www.w3.org/1999/xhtml">
                <message>
                <user>{$currentUser}</user>
                <fullName>{sm:get-account-metadata($currentUser, xs:anyURI("http://axschema.org/namePerson"))}</fullName>
                <description>{sm:get-account-metadata($currentUser, xs:anyURI("http://exist-db.org/security/description"))}</description>
                </message>
            </response>)    
   )
   
else if ($exist:path eq "/") then
    (: forward root path to index.xql :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="index.html"/>
    </dispatch>
    
else if (ends-with($exist:resource, ".html")) then
    (: the html page is run through view.xql to expand templates :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <view>
            <forward url="{$exist:controller}/modules/view.xql"/>
        </view>
		<error-handler>
			<forward url="{$exist:controller}/error-page.html" method="get"/>
			<forward url="{$exist:controller}/modules/view.xql"/>
		</error-handler>
    </dispatch>
    
(: Resource paths starting with $nav-base are loaded from the shared-resources app :)
else if (contains($exist:path, "/$nav-base/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="{$exist:controller}/{substring-after($exist:path, '/$nav-base/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
    
(: Resource paths starting with $shared are loaded from the shared-resources app :)
else if (contains($exist:path, "/$shared/")) then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <forward url="/shared-resources/{substring-after($exist:path, '/$shared/')}">
            <set-header name="Cache-Control" value="max-age=3600, must-revalidate"/>
        </forward>
    </dispatch>
    
else
    (: everything else is passed through :)
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <cache-control cache="yes"/>
    </dispatch>

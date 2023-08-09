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
declare variable $nav-base := '/exist/apps/manuForma';
declare variable $userParam := request:get-parameter("user", ());
declare variable $logout := request:get-parameter("logout", ());

if ($exist:path eq '') then
    <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
        <redirect url="{request:get-uri()}/"/>
    </dispatch>
    
(: Log users in or out :)
else if ($exist:resource = "login") then 
    (util:declare-option("exist:serialize", "method=json media-type=application/json"),
    try {
        let $loggedIn := login:set-user($config:login-domain, (), true())
        let $user := request:get-attribute($config:login-domain || ".user")
        return
           if ($user and sm:list-users() = $user) then
                <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                    <user>{$user}</user>
                </response>
            else if($userParam and sm:list-users() = $userParam) then
                <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                    <user>{$user}</user>
                </response>
            else if($logout = 'true') then 
               <response status="success" xmlns="http://www.w3.org/1999/xhtml" message="success">
                    <success>You have been logged out.</success>
                </response> 
            else (
                <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="Username already exists">
                    <fail>Wrong user or password user: {$user}</fail>
                </response>
            )
    } catch * {
        <response status="fail" xmlns="http://www.w3.org/1999/xhtml" message="{$err:description}">
            <fail>{$err:description}</fail>
        </response>
    })
    
    
(: Check user credentials :)
else if ($exist:resource = "userInfo") then 
    ((:util:declare-option("exist:serialize", "method=json media-type=application/json"),:)
     let $currentUser := 
                if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
                else sm:id()/sm:id/sm:real/sm:username/string(.)
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
(: Restrict forms to logged in users :)   
else if (ends-with($exist:path, "forms.xq")) then (
        login:set-user($config:login-domain, (), true()),
        let $user := request:get-attribute($config:login-domain || ".user")
        let $userParam := request:get-parameter("user","")
        let $logout := request:get-parameter("logout",())
        return
            if($logout = "true") then (
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <redirect url="index.html"/>
                </dispatch>
            )
            else if ($user and sm:list-users() = $user) then
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <cache-control cache="no"/>
                </dispatch>
            else if(not(string($userParam) eq string($user))) then
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <redirect url="index.html"/>
                </dispatch>
            else
                <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                    <forward url="login.html"/>
                </dispatch>
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

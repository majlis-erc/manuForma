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

else if ($exist:resource = "form.xq") then (
    login:set-user("org.exist.login", (), true()),
    let $user := sm:id()/sm:id/sm:real/sm:username/string(.)
    let $form := substring-after($exist:path,'/form/')
    return
        if($user != 'guest') then 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
                <cache-control cache="no"/>
            </dispatch>
       else 
            <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
              <redirect url="index.html?login=required"/>
            </dispatch>
)

(:
 : Login a user via AJAX. Just returns a 401 if login fails.
 :)
else if ($exist:resource eq 'login') then
    let $loggedIn := login:set-user("org.exist.login", (), false())
    let $user := request:get-attribute("org.exist.login.user")
    return (
        util:declare-option("exist:serialize", "method=json"),
        try {
            <status xmlns:json="http://www.json.org" message="{if($logout = 'true') then 'Logged out' else if($user) then 'Success' else 'Fail'}">
                <user>{$user}</user>
                {
                    if ($user) then (
                        for $item in sm:get-user-groups($user) return <groups json:array="true">{$item}</groups>,
                        <dba>{sm:is-dba($user)}</dba>
                    ) else
                        ()
                }
            </status>
        } catch * {
            response:set-status-code(401),
            <status>{$err:description}</status>
        }
    )
else if ($exist:path = "/admin") then (
    login:set-user("org.exist.login", (), true()),
    let $user := request:get-attribute("org.exist.login.user")
    let $route := request:get-parameter("route","")
    return
        <dispatch xmlns="http://exist.sourceforge.net/NS/exist">
            <forward url="index.html">
                <cache-control cache="no"/>
                <set-header name="Cache-Control" value="no-cache"/>
            </forward>
            <view>
                <forward url="{$exist:controller}/modules/view.xql"/>
             </view>
     		<error-handler>
     			<forward url="{$exist:controller}/error-page.html" method="get"/>
     			<forward url="{$exist:controller}/modules/view.xql"/>
     		</error-handler>
        </dispatch>
)   

(: Check user credentials :)
else if ($exist:resource = "userInfo") then 
    ((:util:declare-option("exist:serialize", "method=json media-type=application/json"),:)
     let $currentUser := 
                if(request:get-attribute("org.exist.login.user.user")) then request:get-attribute("org.exist.login.user.user") 
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

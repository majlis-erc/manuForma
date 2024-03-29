xquery version "3.1";

module namespace app="http://localhost/manuForma/templates";

import module namespace templates="http://exist-db.org/xquery/html-templating" ;
import module namespace config="http://localhost/manuForma/config" at "config.xqm";

declare variable $app:navbase {'/exist/apps/manuForma'};

(: Display user info :)
declare 
    %templates:wrap
function app:userinfo($node as node(), $model as map(*)) as map(*) {
    let $user:=         
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user") 
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)
    let $name := if ($user) then sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) else 'Guest'
    let $group := if ($user) then sm:get-user-groups($user) else 'guest'
    return
        map { "user-id" : $user, "user-name" : $name, "user-groups" : $group}
};

declare 
    %templates:wrap
function app:display-userinfo($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user             
    return
       if ($user and not(matches($user,'[gG]uest'))) then
            <div class="content-grey">
                <h1>{$user} : {$name}</h1>
                <h3>Your Records:</h3>
                { 'Work in progress' }
            </div>
        else 
            <div class="content-grey">
                <h1>User : Guest</h1>
                <h3>Please Log in to see you records.</h3>
                { 'Work in progress' }
            </div>
};

(: Login functions :)
(: Activate login module use userManager.xql to login and create new users. :)
declare function app:username-login($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute("org.exist.login.user")) then request:get-attribute("org.exist.login.user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user 
    return
        (if(request:get-parameter("login", "") = 'required') then  
            <script type="text/javascript">
                <![CDATA[
                $(document).ready(function () {
                    $("#loginModal").modal("toggle");
                    });
                ]]>
            </script>
        else(),
        if ($user and not(matches($user,'[gG]uest'))) then
            <ul class="nav navbar-nav" xmlns="http://www.w3.org/1999/xhtml">
                <li>
                    <p class="navbar-btn">
                       <div class="dropdown">
                        <button class="btn btn-sm btn btn-outline-light dropdown-toggle" type="button" data-bs-toggle="dropdown">
                            <span class="glyphicon glyphicon-user"/> {$userName} <span class="caret"></span>
                        </button>
                        <ul class="dropdown-menu">
                          <!--<li><a href="{$app:navbase}/user.html?user={$user}">Account</a></li>-->
                          <li><a href="{$app:navbase}/admin?logout=true" id="logout">Logout</a></li>
                        </ul>
                      </div>
                    </p>
                </li>
            </ul>
        else 
             <ul class="nav navbar-nav" xmlns="http://www.w3.org/1999/xhtml">
                <li>
                    <p class="navbar-btn">
                        <button type="button" class="btn btn-sm btn btn-outline-light" data-bs-toggle="modal" data-bs-target="#loginModal"><span class="bi bi-person"/> Login </button>
                    </p>
                </li>
            </ul>)
};
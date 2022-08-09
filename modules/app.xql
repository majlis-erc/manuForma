xquery version "3.1";

module namespace app="http://localhost/manuForma/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://localhost/manuForma/config" at "config.xqm";

declare variable $app:navbase {'/exist/apps/manuForma'};

(: Display user info :)
declare 
    %templates:wrap
function app:userinfo($node as node(), $model as map(*)) as map(*) {
    let $user:=         
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user") 
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
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user 
    (:let $coursepacks := collection($config:app-root || '/coursepacks')/coursepack[@user = $user]:)            
    return
        <div>
            <h1>{$user} : {$userName}</h1>
            <h3>Your Records:</h3>
            {(:for $coursepack in $coursepacks
             return 
                    <div class="indent">
                        <h4><a href="{$config:nav-base}/coursepack/{string($coursepack/@id)}">{string($coursepack/@title)}</a></h4>
                        <p class="desc">{$coursepack/desc/text()}</p>
                    </div> 
            :) 'Work in progress' }
        </div>
};

(: Login functions :)
(: Activate login module use userManager.xql to login and create new users. :)
declare function app:username-login($node as node(), $model as map(*)) {
    let $user:= 
        if(request:get-attribute($config:login-domain || ".user")) then request:get-attribute($config:login-domain || ".user")
        else(: xmldb:get-current-user():) sm:id()/sm:id/sm:real/sm:username/string(.)    
    let $userName := 
            if(sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson'))) then 
                sm:get-account-metadata($user, xs:anyURI('http://axschema.org/namePerson')) 
            else $user 
    return 
        if ($user and not(matches($user,'[gG]uest'))) then
            <ul class="nav navbar-nav" xmlns="http://www.w3.org/1999/xhtml">
                <li>
                    <p class="navbar-btn">
                       <div class="dropdown">
                        <button class="btn btn-sm btn btn-outline-light dropdown-toggle" type="button" data-bs-toggle="dropdown">
                            <span class="glyphicon glyphicon-user"/> {$userName} <span class="caret"></span>
                        </button>
                        <ul class="dropdown-menu">
                          <li><a href="{$app:navbase}/user.html?user={$user}">Account</a></li>
                          <li><a href="{$app:navbase}/login?logout=true" id="logout">Logout</a></li>
                        </ul>
                      </div>
                    </p>
                </li>
            </ul>
        else 
             <ul class="nav navbar-nav" xmlns="http://www.w3.org/1999/xhtml">
                <li>
                    <p class="navbar-btn">
                        <button type="button" class="btn btn-sm btn btn-outline-light" data-bs-toggle="modal" data-bs-target="#loginModal"><span class="bi bi-person"/> Login</button>
                    </p>
                </li>
            </ul>
};
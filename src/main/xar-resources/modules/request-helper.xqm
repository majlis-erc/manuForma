xquery version "3.1";

module namespace rh = "http://localhost/manuForma/request-helper";

import module namespace request = "http://exist-db.org/xquery/request";

(:~
 : Get a HTTP request parameter.
 : Unlike request:get-parameter this will ignore parameters that have an empty string value.
 :
 : @param $name the name of the HTTP request parameter
 :
 : @return the value of the parameter if it is valid, or the empty sequence.
 :)
declare function rh:request-param($name as xs:string) {
    rh:request-param($name, ())
};

(:~
 : Get a HTTP request parameter.
 : Unlike request:get-parameter this will ignore parameters that have an empty string value, and return the default.
 :
 : @param $name the name of the HTTP request parameter
 : @param $default the default value to return if there is no valid parameter
 :
 : @return the value of the parameter if it is valid, or the default.
 :)
declare function rh:request-param($name as xs:string, $default) {
    let $values := request:get-parameter($name, ())[. ne ""]
    return
        if (exists($values)) then
            $values
        else
            $default
};

(:~
 : Get a HTTP request parameter as a boolean value.
 : Unlike request:get-parameter this will ignore parameters that have an empty string value.
 :
 : @param $name the name of the HTTP request parameter
 :
 : @return the boolean value of the parameter.
 :)
declare function rh:request-param-bool($name as xs:string) as xs:boolean {
    lower-case(rh:request-param($name, "false")[1]) eq "true"
};

(:~
 : Get HTTP request parameters.
 : Unlike request:get-parameter this will ignore parameters that have an empty string value.
 :
 : @param $name-prefix the name prefix of the HTTP request parameters
 :
 : @return a map or the names and values of the parameters if valid, or the empty sequence.
 :)
declare function rh:request-params($name-prefix as xs:string) as map(xs:string, xs:string*)* {
    rh:request-params($name-prefix, ())
};

(:~
 : Get HTTP request parameters.
 : Unlike request:get-parameter this will ignore parameters that have an empty string value, and return the default.
 :
 : @param $name-prefix the name prefix of the HTTP request parameters
 : @param $default the default value to return if there is no valid parameter
 :
 : @return a map or the names and values of the parameters if valid, or the default.
 :)
declare function rh:request-params($name-prefix as xs:string, $default-value) as map(xs:string, xs:string*)* {
    for $name in request:get-parameter-names()[starts-with(., $name-prefix)]
    let $value := rh:request-param($name, $default-value)
    return
        if (exists($value)) then
            map { "name": $name, "value": $value }
        else
            ()
};

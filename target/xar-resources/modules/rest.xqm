xquery version "3.1";

module namespace test="http://exist-db.org/apps/restxq/test";


declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";


declare
    %rest:GET
    %rest:path("/manuforma/api")
    %output:media-type("text/html")
    %output:method("html5")
    %rest:query-param("user", "{$user}", "Guest")
function test:hello($user as xs:string*) {
    let $title := 'Hello '
    return
        <html xmlns="http://www.w3.org/1999/xhtml">
            <head>
                <title>{$title}</title>
            </head>
            <body>
                <h1>{$title , $user}</h1>
            </body>
        </html>
};
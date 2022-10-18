xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

import module namespace config="http://srophe.org/srophe/config" at "modules/config.xqm";
import module namespace sf="http://srophe.org/srophe/facets" at "modules/lib/facets.xql";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

(
   sm:chmod(xs:anyURI($target || '/modules/login-helper.xql'), "rwsr-xr-x"),
   sm:chmod(xs:anyURI($target || '/modules/userManager.xql'), "rwsr-xr-x")
)
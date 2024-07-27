package tink.http.clients;

import haxe.io.Bytes;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.html.XMLHttpRequest;
#if haxe4
import js.lib.Int8Array;
#else
import js.html.Int8Array;
#end

using tink.io.Source;
using tink.CoreApi;

class JsClient implements ClientObject {
  var credentials = false;
  
  public function new(?credentials) {
    if(credentials) this.credentials = true;
  }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future #if (tink_core >= "2") .irreversible #else .async #end(function(cb) {
      switch req.header.url.scheme {
        case null | 'http' | 'https': // null scheme is for urls such as "//google.com/foo" where the scheme of current url is to be reused
          var http = getHttp();
          http.open(req.header.method, req.header.url);
          http.withCredentials = credentials;
          http.responseType = ARRAYBUFFER;
          for(header in req.header) 
            switch header.name {
              case CONTENT_LENGTH | HOST: // browsers doesn't allow setting these headers explicitly
              case _: http.setRequestHeader(header.name, header.value);
            }
          http.onreadystatechange = function() if(http.readyState == 4) { // this is equivalent to onload...
            if(http.status != 0) {
              var headers = switch http.getAllResponseHeaders() {
                case null: [];
                case v: [for(line in v.split('\r\n')) if(line != '') HeaderField.ofString(line)];
              }
              cb(Success(new IncomingResponse(
                new ResponseHeader(http.status, http.statusText, headers),
                switch http.response {
                  case null: cast Source.EMPTY;
                  case v: Bytes.ofData(v);
                }
              )));
            } else {
              // onerror may be able to capture the error, give it a chance first
              haxe.Timer.delay(
                cb.bind(Failure(Error.withData(502, 'XMLHttpRequest Error', {request: req, error: 'Status code is zero'}))),
                1
              );
            }
          }
          http.onerror = function(e) {
            cb(Failure(Error.withData(502, 'XMLHttpRequest Error', {request: req, error: e})));
          }
          if(req.header.method == GET)
            http.send();
          else
            req.body.all().handle(function(chunk) http.send(new Int8Array(chunk.toBytes().getData())));
        case _:
          cb(Failure(Helpers.missingSchemeError(req.header.url)));
      }
    });
  }
  
  #if ie6
  // see: http://stackoverflow.com/a/2557268/3212365
  static var factories:Array<Void->XMLHttpRequest> = [
    function() return new XMLHttpRequest(), // browser compatibility: https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest#Browser_compatibility
    function() return untyped __js__('new ActiveXObject("Msxml2.XMLHTTP")'),
    function() return untyped __js__('new ActiveXObject("Msxml3.XMLHTTP")'),
    function() return untyped __js__('new ActiveXObject("Microsoft.XMLHTTP")'),
  ];
  function getHttp() {
      for(f in factories) try return f() catch(e:Dynamic) {}
      throw 'No compatible XMLHttpRequest object can be found';
  }
  #else
  inline function getHttp() {
      return new XMLHttpRequest();
  }
  #end
  
}

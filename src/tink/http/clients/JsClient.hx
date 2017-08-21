package tink.http.clients;

import haxe.io.Bytes;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.html.XMLHttpRequest;
import js.html.Int8Array;

using tink.io.Source;
using tink.CoreApi;

class JsClient implements ClientObject {
  var secure = false;
  public function new() {}
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return jsRequest(req);
  }
  
  function jsRequest(req:OutgoingRequest) {
    return Future.async(function(cb) {
      var http = getHttp();
      
      var url:String = req.header.url;
      if(req.header.url.scheme == null) url = (secure ? 'https:' : 'http:') + url;
      http.open(req.header.method, url);
      http.withCredentials = true;
      http.responseType = ARRAYBUFFER;
      for(header in req.header) http.setRequestHeader(header.name, header.value);
      http.onreadystatechange = function() if(http.readyState == 4) { // this is equivalent to onload...
        if(http.status != 0) {
          var headers = switch http.getAllResponseHeaders() {
            case null: [];
            case v: [for(line in v.split('\r\n')) {
              if(line != '') {
                var s = line.split(': ');
                new HeaderField(s[0], s.slice(1).join(': '));
              }
            }];
          }
          var header = new ResponseHeader(http.status, http.statusText, headers);
          cb(Success(new IncomingResponse(
            new ResponseHeader(http.status, http.statusText, headers),
            switch http.response {
              case null: cast Source.EMPTY;
              case v: Bytes.ofData(v);
            }
          )));
        } else {
          cb(Failure(new Error(502, 'XMLHttpRequest Error')));
        }
      }
      http.onerror = function(e) {
        cb(Failure(Error.withData(502, 'XMLHttpRequest Error', e)));
      }
      if(req.header.method == GET)
        http.send();
      else
        req.body.all().handle(function(chunk) http.send(new Int8Array(chunk.toBytes().getData())));
    });
  }
  
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
}
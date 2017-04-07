package tink.http.clients;

class JsClient implements ClientObject {
  public function new() {}
  
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    return jsRequest(req, switch req.header.host {
        case null: ''; // TODO: js.Browser.window.location?
        case v: 'http://$v';
    });
  }
  
  function jsRequest(req:OutgoingRequest, host:String) {
    return Future.async(function(cb) {
      var http = getHttp();
      http.open(req.header.method, host + req.header.uri);
      http.responseType = ARRAYBUFFER;
      for(header in req.header.fields) http.setRequestHeader(header.name, header.value);
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
          cb(new IncomingResponse(
            new ResponseHeader(http.status, http.statusText, headers),
            switch http.response {
              case null: Empty.instance;
              case v: Bytes.ofData(v);
            }
          ));
        } else {
          cb(new IncomingResponse(
            new ResponseHeader(502, 'XMLHttpRequest Error', []),
            Empty.instance
          ));
        }
      }
      http.onerror = function() {
        cb(new IncomingResponse(
          new ResponseHeader(502, 'XMLHttpRequest Error', []),
          Empty.instance
        ));
      }
      req.body.all().handle(function(bytes) http.send(new Int8Array(bytes.getData())));
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
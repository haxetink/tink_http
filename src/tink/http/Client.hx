package tink.http;

import tink.http.Message.MessageHeaderField;
import tink.http.Request;
import tink.http.Response;
import tink.io.Worker;

using tink.CoreApi;

interface ClientObject {
  function request(req:OutgoingRequest):Future<IncomingResponse>;
}

class StdClient {
  var worker:Worker;
  public function new() {}
  public function request(req:OutgoingRequest):Future<IncomingResponse> 
    return Future.async(function (cb) {
            
      var r = new haxe.Http('http:'+req.header.fullUri());
      
      function send(post) {
        var code = 200;
        r.onStatus = function (c) code = c;
        
        function headers()
          return 
            switch r.responseHeaders {
              case null: [];
              case v:
                [for (name in v.keys()) 
                  new MessageHeaderField(name, v[name])
                ];
            }
          
        r.onError = function (msg) {
          if (code == 200) code = 500;
          worker.work(true).handle(function () {
            cb(new IncomingResponse(new ResponseHeader(code, 'error', headers()), msg));        
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        r.onData = function (data) {
          
          worker.work(true).handle(function () {
            cb(new IncomingResponse(new ResponseHeader(code, 'OK', headers()), data));
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        worker.work(function () r.request(post));
      }      
      
      for (h in req.header.fields)
        r.setHeader(h.name, h.value);
        
      switch req.header.method {
        case GET | HEAD | OPTIONS:
          send(false);
        default:
          
          //r.setPostData(
      }
    });
}
package tink.http.clients;

import tink.io.Worker;
import tink.http.Client;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;

using tink.CoreApi;
using tink.io.Source;

class StdClient implements ClientObject {
  var worker:Worker;
  
  public function new(?worker:Worker) {
    this.worker = worker.ensure();
  }
  public function request(req:OutgoingRequest):Promise<IncomingResponse> 
    return Future.async(function (cb) {
            
      var r = new haxe.Http(req.header.url);
      
      function send(post) {
        var code = 200;
        r.onStatus = function (c) code = c;
        
        function headers()
          return 
            #if sys
              switch r.responseHeaders {
                case null: [];
                case v:
                  [for (name in v.keys()) 
                    new HeaderField(name, v[name])
                  ];
              }
            #else
              [];
            #end
          
        r.onError = function (msg) {
          if (code == 200) code = 500;
          worker.work(true).handle(function () {
            cb(Failure(new Error(code, msg)));
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        r.onData = function (data) {
          
          worker.work(true).handle(function () {
            cb(Success(new IncomingResponse(new ResponseHeader(code, 'OK', headers()), data)));
          });//TODO: this hack makes sure things arrive on the right thread. Great, huh?
        }
        
        worker.work(function () r.request(post));
      }      
      
      for (h in req.header)
        r.setHeader(h.name, h.value);
        
      switch req.header.method {
        case GET | HEAD | OPTIONS:
          send(false);
        default:
          req.body.all().handle(function(bytes) {
            r.setPostData(bytes.toString());
            send(true);  
        });
      }
    });
}
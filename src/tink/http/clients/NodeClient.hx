package tink.http.clients;

import haxe.DynamicAccess;
import tink.io.Source;
import tink.io.Sink;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.node.http.IncomingMessage;

using tink.CoreApi;

typedef NodeAgent<Opt> = {
  public function request(options:Opt, callback:IncomingMessage->Void):js.node.http.ClientRequest;
}

class NodeClient implements ClientObject {
  
  public function new() { }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    var options:js.node.Http.HttpRequestOptions = {
      method: cast req.header.method,
      path: req.header.url.pathWithQuery,
      host: req.header.url.host.name,
      port: req.header.url.host.port,
      headers: cast {
        var map = new DynamicAccess<String>();
        for (h in req.header)
          map[h.name] = h.value;
        map;
      },
      agent: false,
    }
    return nodeRequest(js.node.Http, options, req);
  }
    
    
  function nodeRequest<A:NodeAgent<T>, T>(agent:A, options:T, req:OutgoingRequest):Promise<IncomingResponse> 
    return 
      Future.async(function (cb) {
        var fwd = agent.request(
          options,
          function (msg:IncomingMessage) cb(Success(new IncomingResponse(
            new ResponseHeader(
              msg.statusCode,
              msg.statusMessage,
              [for (i in 0...msg.rawHeaders.length >> 1) new HeaderField(msg.rawHeaders[2*i], msg.rawHeaders[2*i+1])]
            ),
            Source.ofNodeStream('Response from ${req.header.url}', msg)
          )))
        );
        
        function fail(e:Error)
          cb(Failure(e));
          
        fwd.on('error', function (e:js.Error) fail(Error.withData(e.message, e)));
        
        req.body.pipeTo(
          Sink.ofNodeStream('Request to ${req.header.url}', fwd)
        ).handle(function (res) {
          fwd.end();
          // req.body.close();
          switch res {
            case AllWritten:
            case SinkEnded(_): fail(new Error(502, 'Gateway Error'));
            case SinkFailed(e, _): fail(e);
          }
        });
      });
}
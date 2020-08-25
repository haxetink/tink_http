package tink.http.clients;

import haxe.DynamicAccess;
import tink.io.Source;
import tink.io.Sink;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.node.http.IncomingMessage;
import js.node.http.ClientRequest;

using tink.CoreApi;

typedef NodeAgent<Opt> = {
  public function request(options:Opt, callback:IncomingMessage->Void):ClientRequest;
}

class NodeClient implements ClientObject {
  
  public function new() { }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return switch Helpers.checkScheme(req.header.url.scheme) {
      case Some(e):
        Promise.reject(e);
        case None:
          var options:js.node.Https.HttpsRequestOptions = {
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
          
          if(req.header.url.scheme == 'https')
            nodeRequest(js.node.Https, options, req);
          else
            nodeRequest(js.node.Http, options, req);
    }
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
          
        fwd.on('error', function (e:#if haxe4 js.lib.Error #else js.Error #end) fail(Error.withData(e.message, e)));
        
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
package tink.http.clients;

import js.node.http.Agent;
import haxe.DynamicAccess;
import tink.io.Source;
import tink.io.Sink;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.node.http.IncomingMessage;
import js.node.http.ClientRequest;
import js.node.Https.HttpsRequestOptions;

using tink.CoreApi;

typedef NodeHttp<Opt> = {
  public function request(options:Opt, callback:IncomingMessage->Void):ClientRequest;
}

class NodeClient implements ClientObject {
  final agent:Agent;
  
  public function new(?agent) {
    this.agent = agent;
  }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return switch Helpers.checkScheme(req.header.url) {
      case Some(e):
        Promise.reject(e);
        case None:
          var options = getNodeOptions(req.header);
          
          if(req.header.url.scheme == 'https')
            nodeRequest(js.node.Https, options, req);
          else
            nodeRequest(js.node.Http, options, req);
    }
  }
  
  function getNodeOptions(header:OutgoingRequestHeader):HttpsRequestOptions {
    return {
      agent: agent,
      method: cast header.method,
      path: header.url.pathWithQuery,
      host: header.url.host.name,
      port: header.url.host.port,
      headers: cast {
        var map = new DynamicAccess<Array<String>>();
        for (h in header) {
          var name = h.name;
          if(name == 'host') {
            // HOST header must not be an array
            map[h.name] = cast h.value;
          } else {
            var list = switch map[h.name] {
              case null: map[h.name] = [];
              case arr: arr;
            }
            list.push(h.value);
          }
        }
        map;
      },
    }
  }
    
  function nodeRequest<A:NodeHttp<T>, T>(agent:A, options:T, req:OutgoingRequest):Promise<IncomingResponse> 
    return 
      Future #if (tink_core >= "2") .irreversible #else .async #end(function (cb) {
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
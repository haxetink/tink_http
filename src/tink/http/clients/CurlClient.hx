package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;

using tink.io.Sink;
using tink.io.Source;
using tink.CoreApi;

// Does not restrict to any platform as long as they can run the curl command somehow
class CurlClient implements ClientObject {
  var curl:Array<String>->RealSource->RealSource;
  var protocol:String = 'http';
  public function new(?curl:Array<String>->RealSource->RealSource) {
    this.curl = 
      if(curl != null) curl;
      else {
        #if (sys || nodejs)
          function(args, body) {
            args.push('--data-binary');
            args.push('@-');
            var process = #if sys new sys.io.Process #elseif nodejs js.node.ChildProcess.spawn #end ('curl', args);
            var stdin = #if sys Sink.ofOutput #else Sink.ofNodeStream #end ('stdin', process.stdin);
            var stdout = #if sys Source.ofInput #else Source.ofNodeStream #end ('stdout', process.stdout);
            body.pipeTo(stdin, {end: true}).handle(function(o) switch o {
              case AllWritten: trace('piped'); // good
              case SourceFailed(e) | SinkFailed(e, _): trace(e); // TODO: how to force an error in the returned source?
              case SinkEnded(_): trace("SinkEnded"); // TODO: how to force an error in the returned source?
            });
            return stdout;
          }
        #else
          throw "curl function not supplied";
        #end
      }
  }
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    var args = [];
    
    args.push('-is');
    
    args.push('-X');
    args.push(req.header.method);
    
    switch req.header.protocol {
      case HTTP1_0: args.push('--http1.0');
      case HTTP1_1: args.push('--http1.1');
      case HTTP2: args.push('--http2');
      default:
    }
    
    for(header in req.header) {
      args.push('-H');
      args.push('${header.name}: ${header.value}');
    }
    
    args.push(req.header.url);
    
    return curl(args, req.body)
      .parse(ResponseHeader.parser())
      .next(function (p) return new IncomingResponse(p.a, p.b));
  }
}

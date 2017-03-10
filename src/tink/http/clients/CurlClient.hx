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
  var curl:Array<String>->IdealSource->RealSource;
  var protocol:String = 'http';
  public function new(?curl:Array<String>->IdealSource->RealSource) {
    this.curl = 
      if(curl != null) curl;
      else {
        #if (sys || nodejs)
          function(args, body) {
            args.push('--data-binary');
            args.push('@-');
            var process = #if sys new sys.io.Process #elseif nodejs js.node.ChildProcess.spawn #end ('curl', args);
            var sink = #if sys Sink.ofOutput #else Sink.ofNodeStream #end ('stdin', process.stdin);
            body.pipeTo(sink, {end: true}).eager();
            return #if sys Source.ofInput #else Source.ofNodeStream #end ('stdout', process.stdout);
          }
        #else
          throw "curl function not supplied";
        #end
      }
  }
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    var args = [];
    
    args.push('-is');
    
    args.push('-X');
    args.push(req.header.method);
    
    // TODO: http version
    
    for(header in req.header) {
      args.push('-H');
      args.push('${header.name}: ${header.value}');
    }
    
    args.push(req.header.url);
    
    return curl(args, req.body)
      .parse(ResponseHeader.parser())
      .next(function (p) return new IncomingResponse(p.a, p.b))
      .recover(IncomingResponse.reportError);
  }
}

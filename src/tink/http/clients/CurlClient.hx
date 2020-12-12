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
  
  public function new(?curl:Array<String>->IdealSource->RealSource) {
    if(curl != null) this.curl = curl;
  }
  
  public function request(req:OutgoingRequest, ?handlers:ClientRequestHandlers):Promise<IncomingResponse> {
    return switch Helpers.checkScheme(req.header.url.scheme) {
      case Some(e):
        Promise.reject(e);
      case None:
        var args = [];
        
        args.push('-isS');
        
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
        curl(args, req.body)
          .parse(ResponseHeader.parser())
          .next(function (p) return new IncomingResponse(p.a, p.b));
    }
  }
  
  dynamic function curl(args:Array<String>, body:IdealSource):RealSource {
    #if (sys || nodejs)
      args.push('--data-binary');
      args.push('@-');
      
      #if nodejs
      var process = js.node.ChildProcess.spawn('curl', args);
      var sink = Sink.ofNodeStream('stdin', process.stdin);
      body.pipeTo(sink, {end: true}).eager();
      return Future.async(function(cb) process.once('exit', function(code, signal) cb(code)))
        .next(function(code) return switch code {
          case 0: Source.ofNodeStream('stdout', process.stdout);
          case v: Source.ofNodeStream('stderr', process.stderr).all().next(function(stderr) return new Error(v, stderr.toString()));
        });
      #else
      var process = new sys.io.Process('curl', args);
      var sink = Sink.ofOutput('stdin', process.stdin);
      body.pipeTo(sink, {end: true}).eager();
      return switch process.exitCode() {
        case 0: Source.ofInput('stdout', process.stdout);
        case v: new Error(v, process.stderr.readAll().toString());
      }
      #end
      
    #else
      throw "curl function not supplied";
    #end
  }
}

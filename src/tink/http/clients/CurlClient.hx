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
  final extraArgs:Array<String>;
  
  public function new(?curl:Array<String>->IdealSource->RealSource, ?extraArgs:Array<String>) {
    if(curl != null) this.curl = curl;
    this.extraArgs = extraArgs;
  }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return switch Helpers.checkScheme(req.header.url) {
      case Some(e):
        Promise.reject(e);
      case None:
        final args = switch extraArgs {
          case null: [];
          case v: v.copy();
        }
        
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
          .next(p -> new IncomingResponse(p.a, p.b));
    }
  }
  
  dynamic function curl(args:Array<String>, body:IdealSource):RealSource {
    #if (sys || nodejs)
      args.push('--data-binary');
      args.push('@-');
      
      #if nodejs
      final process = js.node.ChildProcess.spawn('curl', args);
      final stdin = Sink.ofNodeStream('stdin', process.stdin);
      final stdout = Source.ofNodeStream('stdout', process.stdout);
      final stderr = Source.ofNodeStream('stderr', process.stderr);
      
      body.pipeTo(stdin, {end: true}).eager();
      return Future #if (tink_core >= "2") .irreversible #else .async #end(cb -> process.once('exit', (code, signal) -> cb(code)))
        .next(code -> switch code {
          case 0: stdout;
          case v: stderr.all().next(chunk -> new Error(v, chunk.toString()));
        });
      #else
      final process = new sys.io.Process('curl', args);
      final sink = Sink.ofOutput('stdin', process.stdin);
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

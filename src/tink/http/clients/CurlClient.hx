package tink.http.clients;

// Does not restrict to any platform as long as they can run the curl command somehow
class CurlClient implements ClientObject {
  var curl:Array<String>->Source->Source;
  var protocol:String = 'http';
  public function new(?curl:Array<String>->Source->Source) {
    this.curl = 
      if(curl != null) curl;
      else {
        #if (sys || nodejs)
          function(args, body) {
            args.push('--data-binary');
            args.push('@-');
            var process = #if sys new sys.io.Process #elseif nodejs js.node.ChildProcess.spawn #end ('curl', args);
            var sink = #if sys Sink.ofOutput #else Sink.ofNodeStream #end ('stdin', process.stdin);
            body.pipeTo(sink).handle(function(_) sink.close());
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
    
    for(header in req.header.fields) {
      args.push('-H');
      args.push('${header.name}: ${header.value}');
    }
    
    args.push('$protocol:' + req.header.fullUri());
    
    return curl(args, req.body).parse(ResponseHeader.parser()).map(function (o) return switch o {
      case Success({ data: header, rest: body }):
        new IncomingResponse(header, body);
      case Failure(e):
        new IncomingResponse(new ResponseHeader(e.code, e.message, []), (e.message : Source).append(e));
    });
  }
}

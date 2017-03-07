package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;
import tink.io.Source;
import tink.io.Sink;
import tink.io.Worker;

using tink.CoreApi;

class SocketClient implements ClientObject {
  
  var worker:Worker;
  var secure = false;
  
  public function new(?worker:Worker) {
    this.worker = worker.ensure();
  }
  
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    
    return Future.async(function(cb) {
      
      var socket = 
        if(secure)
          #if php new php.net.SslSocket();
          #elseif java new java.net.SslSocket();
          #elseif (!no_ssl && (hxssl || hl || cpp || (neko && !(macro || interp)))) new sys.ssl.Socket();
          #else throw "Https is only supported with -lib hxssl";
          #end
        else
          new sys.net.Socket();
        
      var port = switch req.header.host.port {
        case null: secure ? 443 : 80;
        case v: v;
      }
      
      worker.work(function() socket.connect(new sys.net.Host(req.header.host.name), port)).handle(function(_) {
        var sink = Sink.ofOutput('Request to ${req.header.fullUri()}', socket.output, worker);
        var source = Source.ofInput('Response from ${req.header.fullUri()}', socket.input, worker);
        
        switch req.header.byName('connection') {
          case Success((_:String).toLowerCase() => 'close'): // ok
          case Success(v):
            cb(new IncomingResponse(
              new ResponseHeader(500, 'Unsupported Connection Type', []),
              'Only "Connection: Close" is supported. But specified as "$v"'
            ));
            return;
          case Failure(_): req.header.fields.push(new HeaderField('connection', 'close'));
        }
        
        var data:Source = req.header.toString();
        data = data.append(req.body);
        
        data.pipeTo(sink).map(function(r) {
          switch r {
            case AllWritten:
              source.parse(ResponseHeader.parser()).handle(function(o) switch o {
                case Success(parsed):
                  cb(new IncomingResponse(
                    parsed.data,
                    parsed.rest
                  ));
                case Failure(e):
                  cb(new IncomingResponse(
                    new ResponseHeader(500, 'Header parse error', []),
                    Std.string(e)
                  ));
              });
              
            default: 
              cb(new IncomingResponse(
                new ResponseHeader(500, 'Pipe error', []),
                Std.string(r)
              ));
          }
        });
      });
    });
  }
}
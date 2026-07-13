package tink.http.clients;

import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;
import tink.io.Sink;
import tink.io.Worker;

using tink.io.Source;
using tink.CoreApi;

class SocketClient implements ClientObject {
  
  var worker:Worker;
  
  public function new(?worker:Worker) {
    this.worker = worker.ensure();
  }
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.irreversible(function(cb) {
      switch Helpers.checkScheme(req.header.url) {
        case Some(e):
          cb(Failure(e));
        case None:
          
          function addHeaders(headers:Array<HeaderField>)
            req = new OutgoingRequest(req.header.concat(headers), req.body);
          
          switch req.header.byName('connection') {
            case Success((_:String).toLowerCase() => 'close'):
              // ok
            case Success(v):
              cb(Failure(new Error('Only "Connection: Close" is supported. But specified as "$v"')));
              return;
            case Failure(_):
              addHeaders([new HeaderField('connection', 'close')]);
          }
          
          switch req.header.byName('host') {
            case Success(_): // ok
            case Failure(_):
              var defaultPort = req.header.url.scheme == 'https' ? 443 : 80;
              var host = switch req.header.url.host.port {
                case null: req.header.url.host.name;
                case p if(p == defaultPort): req.header.url.host.name;
                case p: '${req.header.url.host.name}:$p';
              }
              addHeaders([new HeaderField('host', host)]);
          }
          
          var hostname = req.header.url.host.name;
          var socket = createSocket(req.header.url.scheme == 'https', hostname);
            
          var port = switch req.header.url.host.port {
            case null: req.header.url.scheme == 'https' ? 443 : 80;
            case v: v;
          }
          
          worker.work(function() {
            return try { socket.connect( new sys.net.Host(req.header.url.host.name), port); Success(Noise); }
            catch (e:Dynamic) Failure(new Error(Std.string(e))); 
          }).handle(function(outcome : Outcome<Noise, Error>) {
            switch outcome { 
                case Success(_):
                case Failure(e): return cb(Failure(e));
            }
    
            var sink = Sink.ofOutput('Request to ${req.header.url}', socket.output, {worker: worker});
            var source = Source.ofInput('Response from ${req.header.url}', socket.input, {worker: worker});
            
            req.body.prepend(req.header.toString()).pipeTo(sink).handle(function(r) {
              switch r {
                case AllWritten:
                  source.parse(ResponseHeader.parser()).handle(function(o) switch o {
                    case Success(parsed): 
                      switch parsed.a.getContentLength() {
                        case Success(len): cb(Success(new IncomingResponse(parsed.a, parsed.b.limit(len))));
                        case Failure(_): cb(Success(new IncomingResponse(parsed.a, Chunked.decode(parsed.b))));
                      }
                    case Failure(e): cb(Failure(e));
                  });
                  
                case SinkEnded(_): cb(Failure(new Error('Sink ended unexpectedly')));
                case SinkFailed(e, _): cb(Failure(e));
              }
            });
          });
      }
    });
  }
  
  static function createSocket(secure:Bool, hostname:String):sys.net.Socket {
    if (!secure) return new sys.net.Socket();
    #if php
    return new php.net.SslSocket();
    #elseif jvm
      #if (haxe_ver >= 5)
      return new jvm.net.SslSocket();
      #else
      return new java.net.SslSocket();
      #end
    #elseif python
    return new python.net.SslSocket();
    #elseif no_ssl
    throw new Error('HTTPS is disabled (-D no_ssl)');
    #elseif (hl || cpp || eval || neko)
    var s = new sys.ssl.Socket();
    s.setHostname(hostname);
    return s;
    #else
    throw new Error('HTTPS is not supported on this target');
    #end
  }
}

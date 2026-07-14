package tink.http.clients;

import tink.http.Client;
import tink.http.Header;
import tink.http.Response;
import tink.http.Request;
import tink.tcp.*;

using tink.io.Source;
using tink.CoreApi;

@:require('tink_tcp')
class TcpClient implements ClientObject { 
  public function new() {}
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.irreversible(function(cb) {
      switch Helpers.checkScheme(req.header.url) {
        case Some(e): cb(Failure(e));
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
              var url = req.header.url;
              var defaultPort = url.scheme == 'https' ? 443 : 80;
              var host = switch url.host.port {
                case null: url.host.name;
                case p if(p == defaultPort): url.host.name;
                case p: '${url.host.name}:$p';
              }
              addHeaders([new HeaderField('host', host)]);
          }

          var cnx = Connection.establish({
            host: req.header.url.host.name, 
            port: req.header.url.host.port,
            secure: req.header.url.scheme == 'https',
          });
          
          req.body.prepend(req.header.toString()).pipeTo(cnx.sink, {end: true /* implement connection reuse */}).handle(function(o) switch o {
            case AllWritten: // ok
            case SinkFailed(e, _): cb(Failure(e));
            case SinkEnded(_): cb(Failure(new Error('Sink ended')));
          });
          
          cnx.source.parse(ResponseHeader.parser())
            .next(function(parsed)
              return new IncomingResponse(parsed.a, Helpers.frameResponseBody(req.header.method, parsed.a, parsed.b))
            )
            .handle(cb);
      }
    });
  }
}
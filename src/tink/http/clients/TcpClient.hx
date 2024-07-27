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
    return Future #if (tink_core >= "2") .irreversible #else .async #end(function(cb) {
      switch Helpers.checkScheme(req.header.url) {
        case Some(e): cb(Failure(e));
        case None:
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
            .next(function(parsed) return new IncomingResponse(parsed.a, parsed.b))
            .handle(cb);
      }
    });
  }
}
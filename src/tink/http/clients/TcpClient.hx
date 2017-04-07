package tink.http.clients;

class TcpClient implements ClientObject { 
  var secure = false;
  public function new() {}
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    
    var cnx = Connection.establish({
      host: req.header.host.name, 
      port: req.header.host.port,
      secure: secure
    });
    
    req.body.prepend(req.header.toString()).pipeTo(cnx.sink).handle(function (x) {
      cnx.sink.close();//TODO: implement connection reuse
    });
    
    return cnx.source.parse(ResponseHeader.parser()).map(function (o) return switch o {
      case Success({ data: header, rest: body }):
        new IncomingResponse(header, body);
      case Failure(e):
        new IncomingResponse(new ResponseHeader(e.code, e.message, []), (e.message : Source).append(e));
    });
  }
}
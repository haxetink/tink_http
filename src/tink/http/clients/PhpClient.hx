package tink.http.clients;


class PhpClient implements ClientObject {
  var protocol:String = 'http';
  public function new() {}
  
  public function request(req:OutgoingRequest):Future<IncomingResponse> {
    return Future.async(function(cb) {
      req.body.all().handle(function(bytes) {
        var options = php.Lib.associativeArrayOfObject({
          http: php.Lib.associativeArrayOfObject({
            // protocol_version: // TODO: req does not define the version?
            header: req.header.fields.map(function(f) return f.toString()).join('\r\n') + '\r\n',
            method: req.header.method,
            content: cast bytes.getData()
          }),
        });
        var context = untyped __call__('stream_context_create', options);
        var url = '$protocol:' + req.header.fullUri();
        var result = @:privateAccess new sys.io.FileInput(untyped __call__('fopen', url, 'rb', false, context));
        var headers:Source = php.Lib.toHaxeArray(untyped __php__("$http_response_header")).join('\r\n') + '\r\n';
        headers.parse(ResponseHeader.parser()).handle(function(o) switch o {
          case Success(parsed):
            cb(new IncomingResponse(
              parsed.data,
              result.readAll()
            ));
          case Failure(e):
            cb(new IncomingResponse(
              new ResponseHeader(500, 'Header parse error', []),
              Std.string(e)
            ));
        });
      });
    });
  }
}
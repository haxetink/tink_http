import tink.http.Header.HeaderField;
import tink.http.Method;
import tink.http.Multipart;
import tink.http.Request;
import tink.io.IdealSource;
import tink.url.Host;
import haxe.Json;
import tink.http.Response;

using buddy.Should;
using tink.CoreApi;

using Lambda;

typedef Request = {
  ?method: Method,
  uri: String,
  ?headers: Array<HeaderField>,
  ?body: String
}

@colorize
class Runner extends buddy.SingleSuite {
  
  var clients = Context.clients.array();
    
  public function new() {
  describe('tink_http', {
  
    it('should respond', function (done) 
    request({uri: '/'}, function (res)
      return toData(res).map(function(data: Data) {
      data.uri.should.be('/');
      return Noise;
      })
    ).handle(done)
    );
    
    it('should return the http method', function (done) 
    request({uri: '/', method: GET}, function (res)
      return toData(res).map(function(data: Data) {
      data.method.should.be('GET');
      return Noise;
      })
    ).handle(done)
    );
  
  });
  }
  
  function toData(res: IncomingResponse): Future<Data>
    return res.body.all().map(function (o) {
      var raw: String = o.sure().toString();
      var data: Data = null;
    try
    data = Json.parse(raw)
    catch (e: Dynamic)
    throw 'Could not parse response as json:\n$raw\n\n$e';
      return data;
    });
  
  function request(req: Request, test: IncomingResponse -> Future<Noise>)
    return Future.ofMany(clients.map(function(client) {
      var fields = switch req.headers {
        case null: [];
        case v: v.copy();
      }
      if (req.body == null) 
        req.body = '';
      if (req.method == null) 
        req.method = GET;
      var outgoing = new OutgoingRequest(new OutgoingRequestHeader(req.method, new Host('127.0.0.1', Std.parseInt(Env.getDefine('port'))), req.uri, fields), req.body);
      switch req.body.length {
        case 0:
        case v:
          switch outgoing.header.get('content-length') {
            case []:
              fields.push(new HeaderField('content-length', Std.string(v)));
            default:
          }
      }
      return client.request(outgoing).flatMap(test);
    }));
    
}
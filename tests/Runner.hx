import tink.http.Client;
import tink.http.Header.HeaderField;
import tink.http.Method;
import tink.http.Request;
import tink.http.Response.IncomingResponse;
import haxe.Json;

using buddy.Should;
using tink.CoreApi;

using Lambda;

typedef Target = {
  name: String, client: Client
}

@colorize
class Runner extends buddy.SingleSuite {
  
  var clients = [
    for (key in Context.clients.keys())
      {name: key, client: Context.clients.get(key)}
  ];
   
  public function new() {
    function test(target: Target) {
      
      function request(data: ClientRequest)
        return target.client.request(data).flatMap(response);
      
      describe('client ${target.name}', {
        
        it('server should set the http method', function(done)
          request({url: '/'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.method.should.be(Method.GET);
            done();
          })
        );
        
        it('server should set the ip', function(done)
          request({url: '/'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.ip.should.endWith('127.0.0.1');
            done();
          })
        );
        
        it('server should set the url', function(done)
          request({url: '/uri/path?query=a&param=b'}).handle(function(res) {
            res.data.should.not.be(null);
            res.data.uri.should.be('/uri/path?query=a&param=b');
            done();
          })
        );
        
        it('server should set headers', function(done)
          request({
            url: '/uri/path?query=a&param=b', 
            headers: [
              'x-header-a' => 'a',
              'x-header-b' => '123'
            ]
          }).handle(function(res) {
            res.data.should.not.be(null);
            var headers = res.data.headers.map(function (pair)
              return '${pair.name}: ${pair.value}'
            );
            headers.should.contain('x-header-a: a');
            headers.should.contain('x-header-b: 123');
            done();
          })
        );
      
      });
    }
    
    describe('tink_http',
      for (target in clients) test(target)
    );
  }
  
  function response(res: IncomingResponse): Future<{data: Data, res: IncomingResponse}>
    return IncomingResponse.readAll(res).map(function (o) 
      return switch o {
        case Success(bytes):
          var body = bytes.toString();
          var data = null;
          try 
            data = Json.parse(body)
          catch (e: Dynamic)
            throw 'Could not parse response as json:\n"$body"';
          {data: data, res: res}
        default:
          {data: null, res: res}
      }
    );
}
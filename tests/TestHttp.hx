package;

import haxe.DynamicAccess;
import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;
import tink.Url;
import tink.url.*;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestHttp {
  var client:Client;
  var url:Url;
  var converter:IncomingResponse->Promise<EchoedRequest>;
  
  public function new(client, target, secure) {
    this.client = client;
    var schema = secure ? 'https' : 'http';
    switch target {
      case Httpbin:
        url = '$schema://httpbin.org';
        converter = Converters.httpbin;
    }
  }
  
  public function get() {
    client.request(new OutgoingRequest(
      new OutgoingRequestHeader(GET, url + '/get?a=1&b=2', []),
      Source.EMPTY
    )).flatMap(converter).handle(function(o) switch o {
      case Success(echo):
        asserts.assert(echo.query.get('a') == '1');
        asserts.assert(echo.query.get('b') == '2');
        asserts.done();
      case Failure(e):
        asserts.fail(e);
    });
    return asserts;
  }
  
  public function header() {
    client.request(new OutgoingRequest(
      new OutgoingRequestHeader(GET, url + '/headers', [new HeaderField('x-custom-tink', 'tink_http')]),
      Source.EMPTY
    )).flatMap(converter).handle(function(o) switch o {
      case Success(echo):
        asserts.assert(Type.enumEq(echo.headers.byName('x-custom-tink'), Success('tink_http')));
        asserts.done();
      case Failure(e):
        asserts.fail(e);
    });
    return asserts;
  }
}

enum Target {
  Httpbin;
}

class Converters {
  public static function httpbin(res:IncomingResponse):Promise<EchoedRequest> {
    return res.body.all().next(function(chunk) {
      var parsed: {
        headers:DynamicAccess<String>,
        args:DynamicAccess<String>,
      } = haxe.Json.parse(chunk);
      return {
        headers: new Header(
          if(parsed.headers == null)
            []
          else
            [for(name in parsed.headers.keys()) new HeaderField(name, parsed.headers.get(name))]
        ),
        query: {
          var map = new Map();
          if(parsed.args != null) for(name in parsed.args.keys()) map.set(name, parsed.args.get(name));
          map;
        }
      }
    });
  }
}

typedef EchoedRequest = {
  headers:Header,
  query:Map<String, String>,
}
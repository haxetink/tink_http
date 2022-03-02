package;

import haxe.DynamicAccess;
import tink.http.Method;
import tink.http.Client;
import tink.http.clients.*;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;
import tink.Chunk;
import tink.Url;
import tink.unit.*;

using tink.io.Source;
using tink.CoreApi;

@:timeout(20000)
@:asserts
class TestHttp {
  var clientType:ClientType;
  var client:Client;
  var url:Url;
  var converter:Converter;
  var target:Target;
  
  public function new(client:ClientType, target) {
    this.client = switch this.clientType = client {
      #if sys
      case Socket: new SocketClient();
      #end
      #if (js && !nodejs)
      case Js: new JsClient();
      case JsFetch: new JsFetchClient();
      #end
      #if nodejs
      case Node: new NodeClient();
      #end
      #if tink_tcp
      case Tcp: new TcpClient();
      #end
      #if ((nodejs || sys) && !php && !lua)
      case Curl: new CurlClient();
      #end
      #if flash
      case Flash: new FlashClient();
      #end
    }
    
    switch this.target = target {
      case Httpbin(true):
        url = 'https://httpbin.org';
        converter = new HttpbinConverter();
      case Httpbin(false):
        url = 'http://httpbin.org';
        converter = new HttpbinConverter();
      case Local(port):
        url = 'http://localhost:$port';
        converter = new LocalConverter();
    }
  }
  
  @:variant(GET)
  @:variant(POST)
  @:variant(PATCH)
  @:variant(DELETE)
  @:variant(PUT)
  public function method(method:Method) {
    var body:String = null;
    var headers = null;
    switch method {
      case GET: // do nothing
      default: 
        body = 'tink_http $method';
        headers = [
          new HeaderField('content-type', 'text/plain'),
          new HeaderField('content-length', Std.string(body.length)),
        ];
    }
    return request(method, url + '/${(method:String).toLowerCase()}?a=1&b=2', headers, body == null ? null : body)
      .next(function(echo) {
          asserts.assert(echo.query.get('a') == '1');
          asserts.assert(echo.query.get('b') == '2');
          if(body != null) asserts.assert(echo.body == body);
          return asserts.done();
      });
  }
  
  @:variant([new tink.core.Named('x-custom-tink', ['tink_http'])])
  @:variant([new tink.core.Named('x-custom-tink', ['tink_http1', 'tink_http2'])])
  public function headers(fields:Array<Named<Array<String>>>)
    return request(GET, url + '/headers', [for(field in fields) for(value in field.value) new HeaderField(field.name, value)])
      .next(function(echo) {
          switch target {
            #if (js && !nodejs)
            case _ if(clientType == Js): // js client combines multiple same-name headers into a single comma-delimited one (at least in puppeteer)
              for(field in fields) {
                asserts.assert(Type.enumEq(echo.headers.byName(field.name), Success(field.value.join(', '))));
              }
            #end
            case Httpbin(_): // httpbin combines multiple same-name headers into a single comma-delimited one
              for(field in fields) {
                asserts.assert(Type.enumEq(echo.headers.byName(field.name), Success(field.value.join(','))));
              }
            case Local(_):
              for(field in fields) for(value in field.value) {
                var found = false;
                for(result in echo.headers)
                  if(result.name == field.name && result.value == value)
                    found = true;
                asserts.assert(found, '${field.name}: $value" should exists in response');
              }
          }
          return asserts.done();
      });
  
  public function origin()
    return request(GET, url + '/ip')
      .next(function(echo) {
          asserts.assert(echo.origin != null && echo.origin.length > 0);
          return asserts.done();
      });
  
  
  function request(method:Method, url:Url, ?headers:Array<HeaderField>, ?body:IdealSource) {
    if(headers == null) headers = [];
    var header = new OutgoingRequestHeader(method, url, headers);
    if(!header.byName(HOST).isSuccess()) headers.push(new HeaderField(HOST, url.host.toString()));
    return client.request(new OutgoingRequest(
      header,
      body == null ? Source.EMPTY : body
    )).next(converter.convert);
  }
  
}


enum Target {
  Httpbin(secure:Bool);
  Local(port:Int);
}

interface Converter {
  function convert(res:IncomingResponse):Promise<EchoedRequest>;
}

class LocalConverter implements Converter {
  public function new() {}
  public function convert(res:IncomingResponse):Promise<EchoedRequest> {
    return res.body.all().next(function(chunk):EchoedRequest {
      var parsed:Data = haxe.Json.parse(chunk);
      
      return {
        headers: new Header(
          if(Reflect.hasField(parsed, 'headers'))
            [for(h in parsed.headers) new HeaderField(h.name, h.value)]
          else
            []
        ),
        query: {
          var map = new Map();
          if(Reflect.hasField(parsed, 'query'))
            for(name in parsed.query.keys()) map.set(name, parsed.query.get(name));
          map;
        },
        body: Reflect.hasField(parsed, 'body') ? parsed.body : Chunk.EMPTY,
        origin: parsed.ip,
      }
    });
  }
}

class HttpbinConverter implements Converter {
  public function new() {}
  public function convert(res:IncomingResponse):Promise<EchoedRequest> {
    return res.body.all().next(function(chunk):EchoedRequest {
      var parsed: {
        headers:DynamicAccess<String>,
        args:DynamicAccess<String>,
        data:String,
        origin:String,
      } = haxe.Json.parse(chunk);
      
      return {
        headers: new Header(
          if(Reflect.hasField(parsed, 'headers'))
            [for(name in parsed.headers.keys()) new HeaderField(name, parsed.headers.get(name))]
          else
            []
        ),
        query: {
          var map = new Map();
          if(Reflect.hasField(parsed, 'args'))
            for(name in parsed.args.keys()) map.set(name, parsed.args.get(name));
          map;
        },
        body: Reflect.hasField(parsed, 'data') ? parsed.data : Chunk.EMPTY,
        origin: #if python !Reflect.hasField(parsed, 'origin') ? null : #end parsed.origin,
      }
    });
  }
}

typedef EchoedRequest = {
  headers:Header,
  query:Map<String, String>,
  body:Chunk,
  origin:String,
}
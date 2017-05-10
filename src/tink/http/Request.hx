package tink.http;

import haxe.io.Bytes;
import haxe.crypto.Base64;
import tink.http.Message;
import tink.http.Header;
import tink.http.Version;
import tink.url.Host;
import tink.url.Query;
import tink.Url;

using StringTools;
using tink.CoreApi;
using tink.io.StreamParser;
using tink.io.Source;

class RequestHeader extends Header {
  
  public var method(default, null):Method;
  public var url(default, null):Url;
  public var version(default, null):Version;

  public function new(method:Method, url:Url, version:Version = 'HTTP/1.1', fields) {
    this.method = method;
    this.url = url;
    this.version = version;
    super(fields);
  }  

  override function concat(fields:Array<HeaderField>):RequestHeader
    return new RequestHeader(method, url, version, this.fields.concat(fields));

  override public function toString()
    return '$method ${url.pathWithQuery} $version$LINEBREAK'+super.toString();

}

class IncomingRequestHeader extends RequestHeader {
  
  var cookies:Map<String, String>;
  
  function getCookies() {
    if (cookies == null)
      cookies = [for (header in get('cookie')) for (entry in Query.parseString(header, ';')) entry.name => entry.value.toString()];
      
    return cookies;
  }
  
  override function concat(fields:Array<HeaderField>):IncomingRequestHeader
    return new IncomingRequestHeader(method, url, version, this.fields.concat(fields));
  
  /**
   *  List all cookie names
   */
  public function cookieNames()
    return cookies.keys();
  
  /**
   *  Get a single cookie
   */
  public function getCookie(name:String)
    return getCookies()[name];
    
  /**
   *  Get the Authorization header as an Enum
   */
  public function getAuth()
    return getAuthWith(function(s, p) return switch s {
      case 'Basic':
        var decoded = Base64.decode(p).toString();
        switch decoded.indexOf(':') {
          case -1: Failure(new Error('Cannot parse username and password because ":" is missing'));
          case i: Success(Basic(decoded.substr(0, i), decoded.substr(i + 1)));
        }
      case 'Bearer':
        Success(Bearer(p));
      case s:
        Success(Others(s, p));
    });
  
  public function getAuthWith<T>(parser:String->String->Outcome<T, Error>):Outcome<T, Error>
    return byName(AUTHORIZATION).flatMap(function(v:String) return switch v.indexOf(' ') {
        case -1:
          Failure(new Error(UnprocessableEntity, 'Invalid Authorization Header'));
        case i:
          parser(v.substr(0, i), v.substr(i + 1));
    });
  
  /**
   *  Get a StreamParser which can parse a Source into an IncomingRequestHeader
   */
  static public function parser():StreamParser<IncomingRequestHeader>
    return new HeaderParser<IncomingRequestHeader>(function (line, headers) 
      return switch line.split(' ') {
        case [method, url, protocol]:
          Success(new IncomingRequestHeader(cast method, url, protocol, headers));
        default: 
          Failure(new Error(UnprocessableEntity, 'Invalid HTTP header'));
      }
    );
}

class OutgoingRequestHeader extends RequestHeader {
  override function concat(fields:Array<HeaderField>):OutgoingRequestHeader
    return new OutgoingRequestHeader(method, url, version, this.fields.concat(fields));
}

class OutgoingRequest extends Message<OutgoingRequestHeader, IdealSource> {}

class IncomingRequest extends Message<IncomingRequestHeader, IncomingRequestBody> {
  
  public var clientIp(default, null):String;
  
  public function new(clientIp, header, body) {
    this.clientIp = clientIp;
    super(header, body);
  }
  
  static public function parse(clientIp, source:RealSource) 
    return
      source.parse(IncomingRequestHeader.parser())
        .next(function (parts) return switch parts.a.getContentLength() {
          case Success(len): new IncomingRequest(clientIp, parts.a, Plain(parts.b.limit(len)));
          case Failure(e): e;
        });
}

enum IncomingRequestBody {
  Plain(source:RealSource);
  Parsed(parts:StructuredBody);
}

enum Authorization {
  Basic(user:String, pass:String);
  Bearer(token:String);
  Others(scheme:String, param:String);
}
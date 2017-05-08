package tink.http;

import haxe.io.Bytes;
import tink.http.Message;
import tink.http.Header;
import tink.http.Version;
import tink.url.Host;
import tink.url.Query;
import tink.Url;


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
  
  public function cookieNames()
    return cookies.keys();
  
  public function getCookie(name:String)
    return getCookies()[name];
  
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

class OutgoingRequestHeader extends RequestHeader {}

class OutgoingRequest extends Message<OutgoingRequestHeader, IdealSource> {}

class IncomingRequest extends Message<IncomingRequestHeader, IncomingRequestBody> {
  
  public var clientIp(default, null):String;
  
  public function new(clientIp, header, body) {
    this.clientIp = clientIp;
    super(header, body);
  }
  
  static public function parse(clientIp, source:RealSource) 
    return
      source.parse(IncomingRequestHeader.parser()).next(
        function (parts) return new IncomingRequest(clientIp, parts.a, Plain(parts.b))
      );
}

enum IncomingRequestBody {
  Plain(source:RealSource);
  Parsed(parts:StructuredBody);
}
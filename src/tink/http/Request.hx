package tink.http;

import haxe.io.Bytes;
import tink.http.Message;
import tink.http.Header;
import tink.url.Auth;
import tink.url.Host;
import tink.url.Query;
import tink.Url;


using tink.CoreApi;
using tink.io.Source;
using StringTools;

class IncomingRequestHeader extends Header {
  public var method(default, null):Method;
  public var uri(default, null):Url;
  public var version(default, null):String;
  
  public function new(method, uri, version, fields) {
    this.method = method;
    this.uri = uri;
    this.version = version;
    super(fields);
  }
  
  var cookies:Map<String, String>;
  
  function getCookies() {
    if (cookies == null)
      cookies = [for (header in get('cookie')) for (entry in Query.parseString(header, ';')) entry.name => entry.value.toString()];
      
    return cookies;
  }
  
  public function cookieNames() {
    return cookies.keys();
  }
  
  public function getCookie(name:String) {
    return getCookies()[name];
  }
  
  // static public function parser():StreamParser<IncomingRequestHeader>
  //   return new HeaderParser<IncomingRequestHeader>(function (line, headers) 
  //     return switch line.split(' ') {
  //       case [method, url, protocol]:
  //         Success(new IncomingRequestHeader(cast method, url, protocol, headers));
  //       default: 
  //         Failure(new Error(UnprocessableEntity, 'Invalid HTTP header'));
  //     }
  //   );
}

class OutgoingRequestHeader extends Header {
  
  public var method(default, null):Method;
  public var host(default, null):Host;//TODO: do something about validating host names
  public var uri(default, null):Url;
  
  public function new(method, host:Host, ?uri:Url, ?fields) {
    this.method = method;
    this.host = host;
    
    if (uri == null) 
      uri = '/';
      
    @:privateAccess {
      uri = new Url({
        path: switch (uri.path:String) {
          case null | '': '/';
          case _.charAt(0) => '/': uri.path;
          case v: '/$v';
        },
        query: uri.query,
        payload: null,
      });
      Url.makePayload(cast uri);
    };
    
    this.uri = uri;
    
    super(fields);
  }
  
  public function fullUri() {
    return '//$host$uri';//TODO: this should somehow be provided by tink_url
  }
  
  public function toString() {
    var ret = ['$method $uri HTTP/1.1'],
        hasHost = false;
        
    for (f in fields) 
      ret.push(f.toString());
    
    switch get('Host') {
      case []:
        ret.push(new HeaderField('Host', (host:String)).toString());  
      default:
    } 
    
    ret.push('');
    ret.push('');
    
    return ret.join('\r\n');
  }
}

class OutgoingRequest extends Message<OutgoingRequestHeader, IdealSource> {}

class IncomingRequest extends Message<IncomingRequestHeader, IncomingRequestBody> {
  
  public var clientIp(default, null):String;
  
  public function new(clientIp, header, body) {
    this.clientIp = clientIp;
    super(header, body);
  }
  
  // static public function parse(clientIp, source:Source) 
  //   return
  //     source.parse(IncomingRequestHeader.parser()) >> function (parts) return new IncomingRequest(clientIp, parts.data, Plain(parts.rest));
  
}

enum IncomingRequestBody {
  Plain(source:RealSource);
  Parsed(parts:StructuredBody);
}
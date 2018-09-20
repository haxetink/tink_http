package tink.http;

import haxe.crypto.Base64;
import tink.http.Message;
import tink.http.Header;
import tink.http.Protocol;
import tink.url.Query;
import tink.Url;

using tink.CoreApi;
using tink.io.StreamParser;
using tink.io.Source;

class RequestHeader extends Header {
  
  public var method(default, null):Method;
  public var url(default, null):Url;
  public var protocol(default, null):Protocol;

  public function new(method:Method, url:Url, protocol:Protocol = HTTP1_1, fields) {
    this.method = method;
    this.url = url;
    this.protocol = protocol;
    super(fields);
  }  

  override function concat(fields:Array<HeaderField>):RequestHeader
    return new RequestHeader(method, url, protocol, this.fields.concat(fields));

  override public function toString()
    return '$method ${url.pathWithQuery} $protocol$LINEBREAK'+super.toString();

}

class IncomingRequestHeader extends RequestHeader {
  
  var cookies:Map<String, String>;
  
  function getCookies() {
    if (cookies == null)
      cookies = [for (header in get('cookie')) for (entry in Query.parseString(header, ';')) entry.name => entry.value.toString()];
      
    return cookies;
  }
  
  override function concat(fields:Array<HeaderField>):IncomingRequestHeader
    return new IncomingRequestHeader(method, url, protocol, this.fields.concat(fields));
  
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
        var decoded = try Base64.decode(p).toString() catch(e:Dynamic) return Failure(Error.withData('Error in decoding basic auth', e));
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
    
  #if nodejs
  static public function fromIncomingMessage(req:js.node.http.IncomingMessage) {
    return new IncomingRequestHeader(
      cast req.method,
      req.url,
      'HTTP/' + req.httpVersion,
      [for (i in 0...Std.int(req.rawHeaders.length / 2)) 
        new HeaderField(req.rawHeaders[2 * i], req.rawHeaders[2 * i +1])
      ]
    );
  }
  #end
}

class OutgoingRequestHeader extends RequestHeader {
  override function concat(fields:Array<HeaderField>):OutgoingRequestHeader
    return new OutgoingRequestHeader(method, url, protocol, this.fields.concat(fields));
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
        .next(function (parts) return new IncomingRequest(
          clientIp,
          parts.a,
          Plain(switch parts.a.getContentLength() {
            case Success(len):
              parts.b.limit(len);
            case Failure(_):
              switch [parts.a.method, parts.a.byName(TRANSFER_ENCODING)] {
                case [GET | OPTIONS, _]: Source.EMPTY;
                case [_, Success((_:String).split(',').map(StringTools.trim) => encodings)] if(encodings.indexOf('chunked') != -1): Chunked.decode(parts.b);
                case _: return new Error(411, 'Content-Length header missing');
              }
          })
        ));
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
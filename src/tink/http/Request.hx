package tink.http;

import haxe.io.Bytes;
import tink.http.Request.IncomingRequest;
import tink.io.*;
import tink.http.Message;
import tink.http.Header;
import tink.io.StreamParser;
import tink.url.Auth;
import tink.url.Host;


using tink.CoreApi;
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

class OutgoingRequestHeader extends Header {
  
  public var method(default, null):Method;
  public var host(default, null):Host;//TODO: do something about validating host names
  public var uri(default, null):String;
  
  public function new(method, host:Host, ?uri:String, ?fields) {
    this.method = method;
    this.host = host;
    
    if (uri == null) uri = '/';
    else if (uri.charAt(0) != '/')
      uri = '/$uri';
      
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

typedef OutgoingRequest = Message<OutgoingRequestHeader, IdealSource>;

class IncomingRequest extends Message<IncomingRequestHeader, IncomingRequestBody> {
  
  public var clientIp(default, null):String;
  
  public function new(clientIp, header, body) {
    this.clientIp = clientIp;
    super(header, body);
  }
  
  static public function parse(clientIp, source:Source) 
    return
      source.parse(IncomingRequestHeader.parser()) >> function (parts) return new IncomingRequest(clientIp, parts.data, Plain(parts.rest));
  
}

enum IncomingRequestBody {
  Plain(source:Source);
  Parsed(parts:Array<BodyPart>);
}

typedef BodyPart = {
  var name(default, null):String;
  var value(default, null):ParsedParam;
}

enum ParsedParam {
  Value(v:String);
  File(handle:UploadedFile);
}

typedef UploadedFile = {
  var fileName(default, null):String;
  var mimeType(default, null):String;
  var size(default, null):Int;
  function read():Source;
  function saveTo(path:String):Surprise<Noise, Error>;
}
package tink.http;

import tink.io.*;
import tink.http.Message;
import tink.io.StreamParser;


using tink.CoreApi;
using StringTools;

class IncomingRequestHeader extends Header {
  public var method(default, null):Method;
  public var uri(default, null):String;
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
  public var host(default, null):String;//TODO: do something about validating host names
  public var port(default, null):Int;
  public var uri(default, null):String;
  public var auth(default, null):Null<{ var user(default, null):String; var pass(default, null):String; }>;
  
  public function new(method, host, port, uri:String, auth, fields) {
    this.method = method;
    this.host = host;
    this.port = port;
    
    if (uri == null) uri = '/';
    else if (uri.charAt(0) != '/')
      uri = '/$uri';
      
    this.uri = uri;
    this.auth = auth;
    super(fields);
  }
  
  public function fullUri() {
    var auth = 
      if (auth == null) 
        '';
      else 
        '${auth.user.urlEncode()}:${auth.pass.urlEncode()}@';
    
    return '//$auth$host:$port$uri';
  }
  
  public function toString() {
    var ret = ['$method $uri HTTP/1.1'],
        hasHost = false;
        
    for (f in fields) 
      ret.push(f.toString());
    
    switch get('Host') {
      case []:
        ret.push(new HeaderField('Host', '$host:$port').toString());  
      default:
    } 
    
    ret.push('');
    ret.push('');
    
    return ret.join('\r\n');
  }
}

typedef OutgoingRequest = Message<OutgoingRequestHeader, IdealSource>;
class IncomingRequest extends Message<IncomingRequestHeader, Source> {
  
  public var clientIp(default, null):String;
  public function new(clientIp, header, body) {
    this.clientIp = clientIp;
    super(header, body);
  }
}
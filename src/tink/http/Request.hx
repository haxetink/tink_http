package tink.http;

import tink.io.*;
import tink.http.Message;
import tink.io.StreamParser;


using tink.CoreApi;
using StringTools;

class IncomingRequestHeader extends MessageHeader {
  public var method(default, null):Method;
  public var uri(default, null):String;
  public var version(default, null):String;
  
  public function new(method, uri, version, fields) {
    this.method = method;
    this.uri = uri;
    this.version = version;
    super(fields);
  }
}

class OutgoingRequestHeader extends MessageHeader {
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
        ret.push(new MessageHeaderField('Host', '$host:$port').toString());  
      default:
    } 
    
    ret.push('');
    ret.push('');
    
    return ret.join('\r\n');
  }
}

typedef OutgoingRequest = Message<OutgoingRequestHeader, IdealSource>;
typedef IncomingRequest = Message<IncomingRequestHeader, Source>;

class RequestHeaderParser extends ByteWiseParser<IncomingRequestHeader> {
	var header:IncomingRequestHeader;
  var fields:Array<MessageHeaderField>;
	var buf:StringBuf;
	var last:Int = -1;
  
	public function new() {
		this.buf = new StringBuf();
		super();
	}
  
	static var INVALID = Failed(new Error(UnprocessableEntity, 'Invalid HTTP header'));  
        
  override function read(c:Int):ParseStep<IncomingRequestHeader> 
    return
			switch [last, c] {
				case [_, -1]:
					
					if (header == null)
            Progressed;
          else
            Done(header);
					
				case ['\r'.code, '\n'.code]:
					
					var line = buf.toString();
					buf = new StringBuf();
					last = -1;
					
					switch line {
						case '':
              if (header == null)
                INVALID;
              else
                Done(header);
						default:
							if (header == null)
								switch line.split(' ') {
									case [method, url, protocol]:
										this.header = new IncomingRequestHeader(cast method, url, protocol, fields = []);
										Progressed;
									default: 
										INVALID;
								}
							else {
								var s = line.indexOf(':');
								switch [line.substr(0, s), line.substr(s+1).trim()] {
									case [name, value]: 
                    fields.push(new MessageHeaderField(name, value));//urldecode?
								}
								Progressed;
							}
					}
						
				case ['\r'.code, '\r'.code]:
					
					buf.addChar(last);
					Progressed;
					
				case ['\r'.code, other]:
					
					buf.addChar(last);
					buf.addChar(other);
					last = -1;
					Progressed;
					
				case [_, '\r'.code]:
					
					last = '\r'.code;
					Progressed;
					
				case [_, other]:
					
					last = other;
					buf.addChar(other);
					Progressed;
			}
  
}

package tink.http;

import tink.io.*;
import tink.http.Message;

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
  
  public function new(method, host, port, uri, auth, fields) {
    this.method = method;
    this.host = host;
    this.port = port;
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
    
    return '//$auth$host:$port/$uri';
  }
  
}

typedef OutgoingRequest = Message<OutgoingRequestHeader, IdealSource>;
typedef IncomingRequest = Message<IncomingRequestHeader, Source>;
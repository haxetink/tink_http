package tink.http;

import tink.io.*;
import tink.http.Message;

using tink.CoreApi;

class RequestHeader extends MessageHeader {
  public var method(default, null):Method;
  public var url(default, null):String;
  public var version(default, null):String;
  
  public function new(method, url, version, fields) {
    this.method = method;
    this.url = url;
    this.version = version;
    super(fields);
  }
}

typedef OutgoingRequest = Message<RequestHeader, IdealSource>;
typedef IncomingRequest = Message<RequestHeader, Source>;
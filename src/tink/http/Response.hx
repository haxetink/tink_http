package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.core.Error;
import tink.http.Message;
import tink.http.Header;
import tink.io.*;

class ResponseHeader extends Header {
  public var statusCode(default, null):Int;
  public var reason(default, null):String;
  
  public function new(statusCode, reason, fields) {
    this.statusCode = statusCode;
    this.reason = reason;
    super(fields);
  }
  
  public function toString() {    
    var ret = ['HTTP/1.1 $statusCode $reason'];
    
    for (h in fields)
      ret.push(h.toString());
    
    ret.push('');
    ret.push('');
    
    return ret.join('\r\n');
  }  
}

private class OutgoingResponseData extends Message<ResponseHeader, IdealSource> {}

@:forward
abstract OutgoingResponse(OutgoingResponseData) {
  public inline function new(header, body) 
    this = new OutgoingResponseData(header, body);
    
  static function blob(bytes:Bytes, contentType:String)
    return new OutgoingResponse(
      new ResponseHeader(200, 'OK', [new HeaderField('Content-Type', contentType), new HeaderField('Content-Length', Std.string(bytes.length))]), 
      bytes
    );
    
  @:from static function ofString(s:String) 
    return blob(Bytes.ofString(s), 'text/plain');
    
  @:from static function ofBytes(b:Bytes) 
    return blob(b, 'application/octet-stream');
    
  @:from static function ofError(e:Error)
    return new OutgoingResponse(
      new ResponseHeader(e.code, e.message, []),
      e.message
    );
}
typedef IncomingResponse = Message<ResponseHeader, Source>;
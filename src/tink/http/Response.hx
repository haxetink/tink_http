package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.http.Message;
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

@:forward
abstract OutgoingResponse(Message<ResponseHeader, IdealSource>) {
  public inline function new(header, body) 
    this = new Message(header, body);
    
  static function blob(bytes:Bytes, contentType:String)
    return new OutgoingResponse(
      new ResponseHeader(200, 'OK', [new HeaderField('Content-Type', contentType), new HeaderField('Content-Length', Std.string(bytes.length))]), 
      bytes
    );
    
  @:from static function ofString(s:String) 
    return blob(Bytes.ofString(s), 'text/plain');
}
typedef IncomingResponse = Message<ResponseHeader, Source>;
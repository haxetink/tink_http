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
  public var protocol(default, null):String;
  
  public function new(statusCode, reason, fields, ?protocol = 'HTTP/1.1') {
    this.statusCode = statusCode;
    this.reason = reason;
    this.protocol = protocol;
    super(fields);
  }
  
  public function toString() {    
    var ret = ['$protocol $statusCode $reason'];
    
    for (h in fields)
      ret.push(h.toString());
    
    ret.push('');
    ret.push('');
    
    return ret.join('\r\n');
  }
  
  static public function parser():StreamParser<ResponseHeader>
    return new HeaderParser<ResponseHeader>(function (line, headers) 
      return switch line.split(' ') {
        case [protocol, status, reason]:
          Success(new ResponseHeader(Std.parseInt(status), reason, headers, protocol));
        default: 
          Failure(new Error(UnprocessableEntity, 'Invalid HTTP response header'));
      }
    );    
}

private class OutgoingResponseData extends Message<ResponseHeader, IdealSource> {}

@:forward
abstract OutgoingResponse(OutgoingResponseData) {
  public inline function new(header, body) 
    this = new OutgoingResponseData(header, body);
    
  static public function blob(bytes:Bytes, contentType:String)
    return new OutgoingResponse(
      new ResponseHeader(200, 'OK', [new HeaderField('Content-Type', contentType), new HeaderField('Content-Length', Std.string(bytes.length))]), 
      bytes
    );
    
  @:from static function ofString(s:String) 
    return blob(Bytes.ofString(s), 'text/plain');
    
  @:from static function ofBytes(b:Bytes) 
    return blob(b, 'application/octet-stream');
    
  static public function reportError(e:Error) {
    return new OutgoingResponse(
      new ResponseHeader(e.code, e.message, [new HeaderField('Content-Type', 'application/json')]),
      haxe.Json.stringify( {
        error: e.message,
        details: e.data,
        //TODO: add stack trace when it becomes available
      })
    );
  }
  static public function redirect(url:String, permanent = false) {
    var code = permanent ? 301 : 302;
    var message = permanent ? 'Moved Permanently' : 'Found';
    return new OutgoingResponse(
      new ResponseHeader(code, message, [new HeaderField('location', url)]),
        tink.io.IdealSource.Empty.instance
    );
  }
}

typedef IncomingResponse = Message<ResponseHeader, Source>;
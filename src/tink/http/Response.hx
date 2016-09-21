package tink.http;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import tink.core.Error;
import tink.http.Message;
import tink.http.Header;
import tink.io.*;

using tink.CoreApi;

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
    
  static public function blob(?code = 200, bytes:Bytes, contentType:String)
    return new OutgoingResponse(
      new ResponseHeader(code, 'OK', [new HeaderField('Content-Type', contentType), new HeaderField('Content-Length', Std.string(bytes.length))]), 
      bytes
    );
    
  @:from static function ofString(s:String) 
    return blob(Bytes.ofString(s), 'text/plain');
    
  @:from static function ofBytes(b:Bytes) 
    return blob(b, 'application/octet-stream');
    
  static public function reportError(e:Error) {
    return new OutgoingResponse(
      new ResponseHeader(e.code, e.message, [new HeaderField('Content-Type', 'application/json')]),
      haxe.Json.stringify({//TODO: reconsider the wisdom of json encoding this way, since it relies on reflection
        error: e.message,
        details: e.data,
        //TODO: add stack trace when it becomes available
      })
    );
  }
}

class IncomingResponse extends Message<ResponseHeader, Source> {
  
  static public function readAll(res:IncomingResponse) 
    return res.body.all() 
      >> function (b:Bytes) 
        return 
          if (res.header.statusCode >= 400) 
            Failure(Error.withData(res.header.statusCode, res.header.reason, b.toString()))
          else
            Success(b);
        
}
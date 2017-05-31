package tink.http;

import tink.http.Message;
import tink.http.Header;
import tink.Chunk;
import httpstatus.HttpStatusCode;

using tink.io.Source;
using tink.CoreApi;

typedef StatusCode = httpstatus.HttpStatusCode;
typedef Reason = httpstatus.HttpStatusMessage;

class ResponseHeader extends Header {
  
  public var statusCode(default, null):StatusCode;
  public var reason(default, null):Reason;
  public var protocol(default, null):String;
  
  public function new(statusCode:StatusCode, reason:Reason, fields, ?protocol:Protocol = HTTP1_1) {
    this.statusCode = statusCode;
    this.reason = reason;
    this.protocol = protocol;
    super(fields);
  }
  
  override function concat(fields:Array<HeaderField>):ResponseHeader
    return new ResponseHeader(statusCode, reason, this.fields.concat(fields), protocol);
  
  override public function toString():String
    return '$protocol ${statusCode.toInt()} $reason$LINEBREAK' + super.toString();
  
  static public function parser():tink.io.StreamParser<ResponseHeader>
    return new HeaderParser<ResponseHeader>(function (line, headers) 
      return switch line.split(' ') {//TODO: we should probably not split here in the first place.
        case v if(v.length >= 3):
          Success(new ResponseHeader(Std.parseInt(v[1]), v.slice(2).join(' '), headers, v[0]));
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
    
  static public function blob(?code = OK, chunk:Chunk, contentType:String, ?headers)
    return 
        new OutgoingResponse(
          new ResponseHeader(
            code, 
            code, 
            [
              new HeaderField('Content-Type', contentType), 
              new HeaderField('Content-Length', Std.string(chunk.length))
            ].concat(switch headers {
              case null: [];
              case v: v;
            })), 
          chunk
        );
  
  static public function chunked(contentType:String, ?headers, source:IdealSource) {
    //TODO: implement
    
  }
        
  @:from static function ofString(s:String) 
    return blob(s, 'text/plain');
    
  @:from static function ofChunk(c:Chunk) 
    return blob(c, 'application/octet-stream');
    
  static public function reportError(e:Error) {
    return new OutgoingResponse(
      new ResponseHeader(e.code, e.code, [new HeaderField('Content-Type', 'application/json')]),
      haxe.Json.stringify({//TODO: reconsider the wisdom of json encoding this way, since it relies on reflection
        error: e.message,
        details: e.data,
        //TODO: add stack trace when it becomes available
      })
    );
  }
}

class IncomingResponse extends Message<ResponseHeader, RealSource> {
  
  static public function readAll(res:IncomingResponse):Promise<Chunk> 
    return res.body.all().next(function (b)
      return 
        if (res.header.statusCode >= 400) 
          Failure(Error.withData(res.header.statusCode, res.header.reason, b.toString()))
        else
          Success(b)   
    );
            
  static public function reportError(e:Error) {
    return new IncomingResponse(
      new ResponseHeader(e.code, e.code, [new HeaderField('Content-Type', 'application/json')]),
      haxe.Json.stringify({//TODO: reconsider the wisdom of json encoding this way, since it relies on reflection
        error: e.message,
        details: e.data,
        //TODO: add stack trace when it becomes available
      })
    );
  }
        
}

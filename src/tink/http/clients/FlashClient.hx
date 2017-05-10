package tink.http.clients;

import flash.net.*;
import flash.events.*;
import haxe.io.Bytes;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import tink.streams.Stream;
import tink.streams.Accumulator;
import tink.Chunk;

using tink.io.Source;
using tink.CoreApi;

/**
 *  Note: 
 *    - need to compile with `-D network-sandbox` for local-with-network sandbox
 *    - need a socket server (not http server) serving at port 843 to serve the policy file,
 *      a sample policy server can be found in sample/swf
 */
class FlashClient implements ClientObject {
  
  var secure = false;
  
  public function new() {}
  
  function getSocket():Socket
    return new Socket();
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.async(function(cb) {
      
      switch req.header.byName('connection') {
        case Success((_:String).toLowerCase() => 'close'): // ok
        case Success(v):
          cb(Failure(new Error('Only "Connection: Close" is supported. But specified as "$v"')));
          return;
        case Failure(_): @:privateAccess req.header.fields.push(new HeaderField('connection', 'close'));
      }
      
      var socket = getSocket();
      
      var accumulator = new Accumulator<Chunk, Error>();
      socket.addEventListener(ProgressEvent.SOCKET_DATA, function(e:ProgressEvent) {
        var len:Int = socket.bytesAvailable;
        var buf = Bytes.alloc(len);
        socket.readBytes(buf.getData(), 0, len);
        accumulator.yield(Data((buf:Chunk)));
      });
      socket.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
        accumulator.yield(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent) {
        accumulator.yield(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(Event.CLOSE, function(e:Event) {
        accumulator.yield(End);
      });
      socket.addEventListener(Event.CONNECT, function(e:Event) {
        req.body.prepend(req.header.toString()).chunked().forEach(function(chunk:Chunk) {
          socket.writeBytes(chunk.toBytes().getData(), 0, chunk.length);
          return Resume;
        }).handle(function(o) switch o {
          case Depleted: socket.flush();
          case Halted(_): throw 'unreachable';
        });
      });
      
      var source:RealSource = accumulator;
      source.parse(ResponseHeader.parser()).handle(function(o) switch o {
        case Success(parsed):
          switch parsed.a.getContentLength() {
            case Success(len): cb(Success(new IncomingResponse(parsed.a, parsed.b.limit(len))));
            case Failure(e): cb(Failure(e));
          }
        case Failure(e): cb(Failure(e));
      });
      
      var port = switch req.header.url.host.port {
        case null: secure ? 443 : 80;
        case v: v;
      }
      
      try {
        socket.connect(req.header.url.host.name, port);
      } catch(e:Dynamic) {
        cb(Failure(Error.withData('Failed to connect to ${req.header.url}', e)));
      }
    });
  }
}
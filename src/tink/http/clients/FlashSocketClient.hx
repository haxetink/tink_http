package tink.http.clients;

import haxe.io.Bytes;
import tink.http.Client;
import tink.http.Response;
import tink.http.Request;
import tink.http.Header;
import tink.io.Sink;
import tink.io.Worker;
import tink.streams.Stream;

#if openfl
import openfl.net.*;
import openfl.events.*;
#end
#if flash
import flash.net.*;
import flash.events.*;
#end

using tink.io.Source;
using tink.CoreApi;

/**
 *  Note: 
 *    - need to compile with `-D network-sandbox` for local-with-network sandbox
 *    - need a socket server (not http server) serving at port 843 to serve the policy file,
 *      a sample policy server can be found in sample/swf
 */
class FlashSocketClient implements ClientObject {
  
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
      
      var signal = Signal.trigger();
      var source:RealSource = new SignalStream(signal);
      socket.addEventListener(ProgressEvent.SOCKET_DATA, function(e:ProgressEvent) {
        var len:Int = socket.bytesAvailable;
        var buf = Bytes.alloc(len);
        socket.readBytes(buf.getData(), 0, len);
        signal.trigger(Data((buf:Chunk)));
      });
      socket.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
        signal.trigger(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent) {
        signal.trigger(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(Event.CLOSE, function(e:Event) {
        signal.trigger(End);
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
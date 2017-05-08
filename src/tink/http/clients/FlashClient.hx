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

class FlashClient implements ClientObject {
  
  var secure = false;
  
  public function new() {}
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.async(function(cb) {
      var socket = new Socket();
      
      var accumulator = new Accumulator<Chunk, Error>();
      socket.addEventListener(ProgressEvent.SOCKET_DATA, function(e:ProgressEvent) {
        trace('ProgressEvent.SOCKET_DATA', e);
        var len:Int = socket.bytesAvailable;
        var buf = Bytes.alloc(len);
        socket.readBytes(buf.getData(), 0, len);
        accumulator.yield(Data((buf:Chunk)));
      });
      socket.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
        trace('IOErrorEvent.IO_ERROR', e);
        accumulator.yield(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, function(e:SecurityErrorEvent) {
        trace('SecurityErrorEvent.SECURITY_ERROR', e);
        accumulator.yield(Fail(Error.withData('Error reading from ${req.header.url}', e)));
      });
      socket.addEventListener(Event.CLOSE, function(e:Event) {
        trace('Event.CLOSE', e);
        accumulator.yield(End);
      });
      socket.addEventListener(Event.CONNECT, function(e:Event) {
        trace('Event.CONNECT', e);
        req.body.prepend(req.header.toString()).chunked().forEach(function(chunk:Chunk) {
          socket.writeBytes(chunk.toBytes().getData(), 0, chunk.length);
          trace('write ${chunk.length} bytes');
          socket.flush();
          return Resume;
        }).handle(function(o) switch o {
          case Depleted: // ok
          case Halted(_): throw 'unreachable';
        });
      });
      
      var source:RealSource = accumulator;
      source.parse(ResponseHeader.parser()).handle(function(o) switch o {
        case Success(parsed): cb(Success(new IncomingResponse(parsed.a, parsed.b)));
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
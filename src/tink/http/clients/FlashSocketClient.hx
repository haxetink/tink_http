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
  
  public function new() {}
  
  function getSocket(secure:Bool):Socket
    return secure ? new SecureSocket() : new Socket();
  
  public function request(req:OutgoingRequest):Promise<IncomingResponse> {
    return Future.irreversible(function(cb) {
      
      function addHeaders(headers:Array<HeaderField>)
        req = new OutgoingRequest(req.header.concat(headers), req.body);
      
      switch req.header.byName('connection') {
        case Success((_:String).toLowerCase() => 'close'):
          // ok
        case Success(v):
          cb(Failure(new Error('Only "Connection: Close" is supported. But specified as "$v"')));
          return;
        case Failure(_):
          addHeaders([new HeaderField('connection', 'close')]);
      }
      
      switch req.header.byName('host') {
        case Success(_): // ok
        case Failure(_):
          var defaultPort = req.header.url.scheme == 'https' ? 443 : 80;
          var host = switch req.header.url.host.port {
            case null: req.header.url.host.name;
            case p if(p == defaultPort): req.header.url.host.name;
            case p: '${req.header.url.host.name}:$p';
          }
          addHeaders([new HeaderField('host', host)]);
      }
      
      var secure = req.header.url.scheme == 'https';
      var socket = getSocket(secure);
      
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
          var body = switch parsed.a.byName(TRANSFER_ENCODING) {
            case Success((_:String).toLowerCase().split(',').map(StringTools.trim) => encodings) if(encodings.indexOf('chunked') != -1):
              Chunked.decode(parsed.b);
            case _:
              switch parsed.a.getContentLength() {
                case Success(len): parsed.b.limit(len);
                case Failure(_): parsed.b; // no framing info: read until the connection closes
              }
          }
          cb(Success(new IncomingResponse(parsed.a, body)));
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
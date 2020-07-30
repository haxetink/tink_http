package tink.http.containers;

import tink.http.Container;
import tink.http.Request;
import tink.http.Header;
import tink.io.*;
import js.node.http.*;

import #if haxe4 js.lib.Error #else js.Error #end as JsError;

using tink.CoreApi;

class NodeContainer implements Container {
  
  var kind:ServerKind;
  var upgradable:Bool;
  
  public function new(kind:ServerKind, ?opt:{?upgradable:Bool}) {
    this.kind = kind;
    this.upgradable = opt != null && opt.upgradable;
  }
        
  static public function toUpgradeHandler(handler:Handler)
    return 
      function (req:js.node.http.IncomingMessage, socket:js.node.net.Socket, head:js.node.Buffer) {
        handler.process(
          new IncomingRequest(
            req.socket.remoteAddress, 
            IncomingRequestHeader.fromIncomingMessage(req),
            Plain(Source.ofNodeStream('Incoming HTTP message from ${req.socket.remoteAddress}', socket)))
        ).handle(function (out) {
          out.body.prepend(out.header.toString()).pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${req.socket.remoteAddress}', socket)).handle(function (_) {
            socket.end();
          });
        });
      }
  
  
  public function run(handler:Handler) 
    return Future.async(function (cb) {
      var failures = Signal.trigger();
      
      var server = switch kind {
        case Instance(server):
          server;
          
        case Port(port):
          var server = new Server();
          server.listen(port);
          server;
          
        case Host(host):
          var server = new Server();
          server.listen(host.port, host.name);
          server;
          
        case Path(path):
          var server = new Server();
          server.listen(path);
          server;
          
        case Fd(fd):
          var server = new Server();
          server.listen(fd);
          server;
      }
      
      function tinkify(e:JsError)
        return Error.withData(e.message, e);
        
      server.on('error', function (e) {
        cb(Failed(e));
      });
      
      if(upgradable)
        server.on('upgrade', toUpgradeHandler(handler));
      
      function onListen() {
        cb(Running({ 
          shutdown: function (hard:Bool) {
            if (hard)
              trace('Warning: hard shutdown not implemented');
              
            return Future.async(function (cb) {
              server.close(function () cb(true));
            });
          },
          failures: failures,//TODO: these need to be triggered
        }));
      }
      
      if(untyped server.listening) // .listening added in v5.7.0, not added to hxnodejs yet
        onListen()
      else
        server.on('listening', onListen);
      
      server.on('request', handler.toNodeHandler());
      server.on('error', function(e) cb(Failed(e)));
    });
}

private enum ServerKindBase {
  Instance(server:Server);
  Port(port:Int);
  Host(host:tink.url.Host);
  Path(path:String);
  Fd(fd:{fd:Int});
}

abstract ServerKind(ServerKindBase) from ServerKindBase to ServerKindBase {
  @:from
  public static inline function fromInstance(server:Server):ServerKind
    return Instance(server);
    
  @:from
  public static inline function fromPort(port:Int):ServerKind
    return Port(port);
  
  @:from
  public static inline function fromHost(host:tink.url.Host):ServerKind
    return Host(host);
  
  @:from
  public static inline function fromPath(path:String):ServerKind
    return Path(path);
  
  @:from
  public static inline function fromFd(fd:{fd:Int}):ServerKind
    return Fd(fd);
}

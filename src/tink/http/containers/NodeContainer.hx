package tink.http.containers;

import tink.http.Container;
import tink.http.Request;
import tink.http.Header;
import tink.io.*;

using tink.CoreApi;

class NodeContainer implements Container {
  
  var port:Int;
  
  public function new(port) {
    this.port = port;
  }
  
  static public function toNodeHandler(handler:Handler)
    return 
      function (req:js.node.http.IncomingMessage, res:js.node.http.ServerResponse)
        handler.process(
          new IncomingRequest(
            req.socket.remoteAddress, 
            new IncomingRequestHeader(cast req.method, req.url, 'HTTP/' + req.httpVersion, [for (i in 0...Std.int(req.rawHeaders.length / 2)) new HeaderField(req.rawHeaders[2 * i], req.rawHeaders[2 * i +1])]), 
            Plain(Source.ofNodeStream('Incoming HTTP message from ${req.socket.remoteAddress}', req)))
        ).handle(function (out) {
          res.writeHead(out.header.statusCode, out.header.reason, cast [for (h in out.header) [(h.name : String), h.value]]);//TODO: readable status code
          out.body.pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${req.socket.remoteAddress}', res)).handle(function (x) {
            res.end();
          });
        });
        
  static public function toUpgradeHandler(handler:Handler)
    return 
      function (req:js.node.http.IncomingMessage, socket:js.node.net.Socket, head:js.node.Buffer) {
        handler.process(
          new IncomingRequest(
            req.socket.remoteAddress, 
            new IncomingRequestHeader(cast req.method, req.url, 'HTTP/' + req.httpVersion, [for (i in 0...Std.int(req.rawHeaders.length / 2)) new HeaderField(req.rawHeaders[2 * i], req.rawHeaders[2 * i +1])]), 
            Plain(Source.ofNodeStream('Incoming HTTP message from ${req.socket.remoteAddress}', socket)))
        ).handle(function (out) {
          out.body.prepend(out.header.toString()).pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${req.socket.remoteAddress}', socket)).handle(function (_) {});
        });
      }
  
  
  public function run(handler:Handler) 
    return Future.async(function (cb) {
      var failures = Signal.trigger();
      var server = js.node.Http.createServer(toNodeHandler(handler));
      
      function tinkify(e:js.Error)
        return Error.withData(e.message, e);
        
      server.on('error', function (e) {
        cb(Failed(e));
      });
      
      server.on('upgrade', toUpgradeHandler(handler));
      
      server.listen(port, function () {
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
      });      
    });
}

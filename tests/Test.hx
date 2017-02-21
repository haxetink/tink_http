package ;

import tink.http.containers.NodeContainer;
import tink.http.containers.TcpContainer;
import tink.http.Response;

using tink.CoreApi;

class Test {
  static function main() {
    haxe.Log.trace = function (v:Dynamic, ?pos:haxe.PosInfos) {
      js.Node.console.log(pos.fileName + ':' + pos.lineNumber, v);
    }
    var port = tink.tcp.nodejs.NodejsAcceptor.inst.bind.bind(12345);
    var c = new TcpContainer(port);
    c.run(function (req) {
      return Future.sync(('hello, world' : OutgoingResponse));
    });
  }
}
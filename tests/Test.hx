package ;

import tink.http.containers.NodeContainer;
import tink.http.containers.TcpContainer;
import tink.http.Response;

using tink.CoreApi;

class Test {
  static function main() {
    var c = new TcpContainer(12345);
    c.run(function (req) {
      return Future.sync(('hello, world' : OutgoingResponse));
    });
  }
}
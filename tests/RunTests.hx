package;

import tink.http.Container;
import tink.http.Client;
import tink.http.Multipart;
import haxe.unit.TestRunner;

class RunTests {

  static function main() {
    #if interp
    
    #elseif (neko || java || cpp)
    var c = new TcpClient();
    var s = new TcpContainer(2000);
    #elseif nodejs
    var c = new NodeClient();
    var s = new NodeContainer(2000);
    #end
    
    var t = new TestRunner();
    t.add(new TestCookie());
    if(!t.run()) {
        #if sys Sys.exit(500); #end
    }
  }
  
}
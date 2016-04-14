package;

import tink.http.Container;
import tink.http.Client;
import tink.http.Multipart;

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
  }
  
}
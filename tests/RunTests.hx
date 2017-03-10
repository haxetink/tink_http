package;

import tink.testrunner.*;
import tink.unit.*;
import tink.http.clients.*;

class RunTests {
  static function main() {
    
    var port = switch Env.getDefine('port') {
      case null: null;
      case v: Std.parseInt(v);
    }
    
    var tests = [];
    
    for(client in Context.clients) {
        tests = tests.concat([
          TestSuite.make(new TestHttp(client, Httpbin, false), '$client -> Httpbin'),
          TestSuite.make(new TestHttp(client, Httpbin, true), '$client -> Httpbin (secure)'),
        ]);
        
        if(port != null) tests = tests.concat([
          TestSuite.make(new TestHttp(client, Local(port), false), '$client -> Local(port = $port)'),
        ]);
    }
    
    Runner.run(tests).handle(Runner.exit);
    
  }
}
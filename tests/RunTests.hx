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
    
    var tests = TestBatch.make([
    #if !container_only
      new TestHeader(),
    #end
    ]);
    
    for(client in Context.clients) {
      #if !container_only
      tests = tests.concat([
        TestSuite.make(new TestHttp(client, Httpbin, false), '$client -> http://httpbin.org'),
        TestSuite.make(new TestHttp(client, Httpbin, true), '$client -> https://httpbin.org'),
      ]);
      #end
      
      if(port != null) tests = tests.concat([
        TestSuite.make(new TestHttp(client, Local(port), false), '$client -> http://localhost:$port'),
      ]);
    }
    
    Runner.run(tests).handle(Runner.exit);
    
  }
}
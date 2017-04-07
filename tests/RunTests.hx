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
    
    var tests = [
      TestSuite.make(new TestHttp(Node, Httpbin, false), 'Httpbin'),
      // TestSuite.make(new TestHttp(Node, Httpbin, true), 'Httpbin (secure)'),
    ];
    
    if(port != null) tests = tests.concat([
      TestSuite.make(new TestHttp(Node, Local(port), false), 'Local'),
    ]);
    
    Runner.run(tests).handle(Runner.exit);
  }
}
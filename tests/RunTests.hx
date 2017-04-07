package;

import tink.testrunner.*;
import tink.unit.*;
import tink.http.clients.*;
import TestHttp;

class RunTests {
  static function main() {
    Runner.run(TestBatch.make([
      // new TestHttp(Node, Httpbin),
      // new TestSecureHttp(Node, Httpbin),
      new TestHttp(Node, Local(8192)),
    ])).handle(Runner.exit);
  }
}

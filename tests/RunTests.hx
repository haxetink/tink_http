package;

import tink.testrunner.*;
import tink.unit.*;
import tink.http.clients.*;

class RunTests {
  static function main() {
    Runner.run(TestBatch.make([
      new TestHttp(new NodeClient(), Httpbin, false),
      new TestHttp(new SecureNodeClient(), Httpbin, true),
    ])).handle(Runner.exit);
  }
}

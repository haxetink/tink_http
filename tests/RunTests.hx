package;

import tink.testrunner.*;
import tink.unit.*;
import tink.http.clients.*;

class RunTests {
  static function main() {
    Runner.run(TestBatch.make([
      new TestHttpbin(Node),
      new TestSecureHttpbin(Node),
      new TestLocal(Node, 8192),
    ])).handle(Runner.exit);
  }
}

class TestHttpbin extends TestHttp {
  public function new(client)
    super(client, Httpbin, false);
}

class TestSecureHttpbin extends TestHttp {
  public function new(client)
    super(client, Httpbin, true);
}

class TestLocal extends TestHttp {
  public function new(client, port)
    super(client, Local(port), false);
}

class TestSecureLocal extends TestHttp {
  public function new(client, port)
    super(client, Local(port), true);
}
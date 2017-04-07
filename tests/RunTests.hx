package;

import tink.testrunner.*;
import tink.unit.*;
import tink.http.clients.*;
import TestHttp;

class RunTests {
  static function main() {
    Runner.run(TestBatch.make([
      new TestHttpbin(Node),
      new TestSecureHttpbin(Node),
      new TestLocal(Node, 8192),
    ])).handle(Runner.exit);
  }
}

class TestHttpbin extends TestHttpBase {
  public function new(client)
    super(client, Httpbin, false);
}

class TestSecureHttpbin extends TestHttpBase {
  public function new(client)
    super(client, Httpbin, true);
}

class TestLocal extends TestHttpBase {
  public function new(client, port)
    super(client, Local(port), false);
}

class TestSecureLocal extends TestHttpBase {
  public function new(client, port)
    super(client, Local(port), true);
}
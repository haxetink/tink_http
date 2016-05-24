package;
import tink.http.containers.PhpContainer;

class RunPhp {

  static function main() {
    PhpContainer.inst.run(DummyServer.handleRequest);
  }
  
}
package;

import tink.http.containers.ModnekoContainer;

class RunNeko {

  static function main() {
    ModnekoContainer.inst.run(DummyServer.handleRequest);
  }
  
}
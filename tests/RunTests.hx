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
      new Sses(),
      new TestChunked(),
      new TestResponseFraming(),
      new FetchTest(#if php Php #end),
    #end
    ]);
    
    #if !no_client
    for(client in Context.clients) {
      #if !container_only
        tests.push(TestSuite.make(new TestHttp(client, Httpbin(false)), '$client -> http://httpbin.io'));
        #if (cs || lua) if(client != Socket) #end // no support for ssl socket yet
        tests.push(TestSuite.make(new TestHttp(client, Httpbin(true)), '$client -> https://httpbin.io'));
      #end
      
      if(port != null) tests = tests.concat([
        TestSuite.make(new TestHttp(client, Local(port)), '$client -> http://localhost:$port'),
      ]);
    }
    #end
    
    Runner.run(tests).handle(Runner.exit);
    
  }
}
import tink.http.Client;
import tink.http.Header.HeaderField;
import tink.http.Method;
import tink.http.Request;
import tink.http.Response.IncomingResponse;
import haxe.Json;

using buddy.Should;
using tink.CoreApi;

using Lambda;

typedef Target = {
  name: String, client: Client
}

class TestSuite extends buddy.BuddySuite {
  
  var clients: Array<Target> = [
    for (key in Context.clients.keys())
      {name: key, client: Context.clients.get(key)}
  ];
  
  function response(res: IncomingResponse): Future<{data: Data, res: IncomingResponse}>
    return IncomingResponse.readAll(res).map(function (o) 
      return switch o {
        case Success(bytes):
          var body = bytes.toString();
          var data = null;
          try 
            data = Json.parse(body)
          catch (e: Dynamic)
            throw 'Could not parse response as json:\n"$body"';
          {data: data, res: res}
        default:
          throw 'Could not read response body';
      }
    );
    
}
# Quick Start

## Install

#### With Haxelib

`haxelib install tink_http`

#### With Lix

`lix install haxelib:tink_http`

## First Web Server

```haxe
import tink.http.Handler;
import tink.http.containers.*;
import tink.http.Response;
using tink.CoreApi;

class Server {
	static function main() {
		var container = new NodeContainer(8080);
		container.run(Handler.ofFunc(function(req) return Future.sync(('Hello, World!':OutgoingResponse))))
			.handle(function(result) switch result {
				case Running(state):
					trace('Server running on http://localhost:8080');
					state.failures.handle(function(f) trace('Request failed:', f.error));
				case Failed(e): trace(e);
				case Shutdown: trace('shutdown');
			});
	}
}
```

1. Copy the code above and save it as `Server.hx`
1. Build it with: `haxe -js server.js -lib hxnodejs -lib tink_http -main Server`
1. Run the server: `node server.js`
1. Navigate to `http://localhost:8080` and you should see `Hello, World!`

`container.run()` returns a `Future<ContainerResult>`. For persistent servers such as `NodeContainer`, the result is `Running`, which provides a `shutdown(hard)` method and a `failures` signal for per-request errors.

## First Web Client

With the server from the previous section still running:

```haxe
import tink.http.Client.*;
using tink.CoreApi;

class Client {
	static function main() {
		fetch('http://localhost:8080').all()
			.handle(function(o) switch o {
				case Success(res): trace(res.body.toString()); // should trace "Hello, World!"
				case Failure(e): trace(e);
			});
	}
}
```

1. Copy the code above and save it as `Client.hx`
1. Build it with: `haxe -js client.js -lib hxnodejs -lib tink_http -main Client`
1. Run it: `node client.js`, and you should see `Hello, World!` printed on screen

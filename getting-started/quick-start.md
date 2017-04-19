# Quick Start

## Install

#### With Haxelib

`haxelib install tink_http`

#### With Lix

`lix install haxelib:tink_http`

## First Web Server

```haxe
import tink.http.containers.*;
import tink.http.Response;

class Server {
	static function main() {
		var container = new NodeContainer(8080);
		container.run(function(req) return Future.sync(('Hello, World!':OutgoingResponse)));
	}
}
```

1. Copy the code above and save it as `Server.hx`
1. Build it with: `haxe -js server.js -lib hxnodejs -lib tink_http -main Server`
1. Run the server: `node server.js`
1. Now navigates to `http://localhost:8080` and you should see `Hello, World!`

## First Web Client

```haxe
import tink.http.clients.*;
import tink.http.Request;
using tink.io.Source;

class Client {
	static function main() {
		var client = new SecureNodeClient();
		client.request(new OutgoingRequest(new OutgoingRequestHeader(GET, 'https://www.google.com', []), ''))
			.next(function(res) return res.body.all())
			.handle(function(o) switch o {
				case Success(body): trace(body); // should trace an html page
				case Failure(e): trace(e);
			});
	}
}
```

1. Copy the code above and save it as `Client.hx`
1. Build it with: `haxe -js client.js -lib hxnodejs -lib tink_http -main Client`
1. Run it: `node client.js`, and you should see whole bunch of html code printed on screen
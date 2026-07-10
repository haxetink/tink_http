# Containers

A **container** is the server runtime that accepts HTTP connections and dispatches them to a [Handler](server.md). All containers implement the same interface:

```haxe
interface Container {
  function run(handler:Handler):Future<ContainerResult>;
}

enum ContainerResult {
  Running(running:RunningState);
  Failed(e:Error);
  Shutdown;
}

typedef RunningState = {
  var failures(default, null):Signal<ContainerFailure>;
  function shutdown(hard:Bool):Promise<Bool>;
}
```

- **`Running`** — the server is up (persistent containers such as Node.js). Use `shutdown(hard)` to stop and subscribe to `failures` for per-request errors.
- **`Failed`** — the container could not start.
- **`Shutdown`** — the container has stopped (one-shot containers such as PHP).

## NodeContainer

Node.js persistent HTTP server.

```haxe
import tink.http.containers.NodeContainer;
using tink.CoreApi;

var container = new NodeContainer(8080);
// or: new NodeContainer({ host: 'localhost', port: 8080 })
// or: new NodeContainer('/tmp/socket.sock')  // Unix domain socket path
// or: new NodeContainer(existingHttpServer)

container.run(handler).handle(/* ... */);
```

`ServerKind` can be constructed from:

- A port number (`8080`)
- `{ host, port }`
- A Unix domain socket path
- A file descriptor
- An existing `http.Server` or `https.Server`

Pass `{ upgradable: true }` to enable WebSocket upgrade handling via `NodeContainer.toUpgradeHandler()`.

## LocalContainer

In-process server for testing. Pair with `LocalContainerClient` or `ClientType.Local(container)` — see [Clients](clients.md).

```haxe
var container = new LocalContainer();
container.run(handler);
// client side: Client.fetch(url, { client: Local(container) })
```

## PhpContainer / ModnekoContainer

For PHP and Neko SAPI environments. Use the static instance and call `run()` from your entry point:

```haxe
PhpContainer.inst.run(handler);
// ModnekoContainer.inst.run(handler);
```

These containers automatically parse multipart form data into `IncomingRequestBody.Parsed`. See [Multipart](multipart.md).

## TcpContainer

Raw TCP HTTP server via the `tink_tcp` library:

```haxe
import tink.http.containers.TcpContainer;

var container = new TcpContainer(function() return tink.tcp.Port.open(8080));
container.run(handler);
```

`TcpContainer.wrap(handler)` converts a tink_http `Handler` into a `tink.tcp.Handler`.

## AwsLambdaNodeContainer

AWS API Gateway Lambda proxy integration. Exports a handler function by name:

```haxe
var container = new AwsLambdaNodeContainer('index', ?isBinary);
container.run(handler).eager(); // must run synchronously in main()
```

## FirebaseFunctionsContainer

Firebase HTTPS functions. Exports a function via `exports[name]`:

```haxe
var container = new FirebaseFunctionsContainer('addMessage', ?regions, ?options);
container.run(handler).eager(); // must run synchronously in main()
```

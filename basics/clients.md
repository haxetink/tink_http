# Clients

A **client** performs HTTP requests. The core interface is:

```haxe
interface ClientObject {
  function request(req:OutgoingRequest):Promise<IncomingResponse>;
}
```

`Client` is an abstract over `ClientObject` with convenience methods `fetch()` and `augment()`. See [Client](client.md) and [Fetch](fetch.md).

## Platform Clients

Each target platform has a default client implementation:

| Client | Target | Notes |
|--------|--------|-------|
| `NodeClient` | nodejs | Default on Node.js; optional `http.Agent` |
| `JsClient` | js | Default in browser; uses XHR |
| `SocketClient` | sys | Default on sys; raw TCP, `Connection: close` only |
| `FlashClient` | flash / openfl | Default on Flash/OpenFL |
| `StdClient` | any with `haxe.Http` | Portable fallback |
| `CurlClient` | sys, nodejs | Shells out to `curl` |
| `PhpClient` | php | PHP streams |
| `TcpClient` | tink_tcp | Requires `tink_tcp` library |
| `LocalContainerClient` | any | Talks to a `LocalContainer` in-process |
| `JsFetchClient` | js | Browser Fetch API; use `ClientType.Custom(new JsFetchClient())` |
| `FlashSocketClient` | flash | Raw sockets; requires Flash policy server |

Instantiate directly when you need fine-grained control:

```haxe
var client:Client = new NodeClient();
client.request(new OutgoingRequest(
  new OutgoingRequestHeader(GET, 'http://localhost:8080'),
  Source.EMPTY
));
```

## ClientType

The [fetch](fetch.md) API selects a client via `ClientType`:

| Variant | Resolves to |
|---------|-------------|
| `Default` | Platform default (`NodeClient`, `JsClient`, `SocketClient`, or `FlashClient`) |
| `Local(c)` | `LocalContainerClient(c)` |
| `Curl` | `CurlClient` (sys \|\| nodejs) |
| `StdLib` | `StdClient` |
| `Custom(c)` | Any `Client` instance |
| `Php` | `PhpClient` (php) |
| `Tcp` | `TcpClient` (tink_tcp) |
| `Flash` / `OpenFl` | `FlashClient` |

`Fetch` caches one client instance per `ClientType` variant.

```haxe
Client.fetch('http://localhost:8080', { client: Curl });
Client.fetch('http://localhost:8080', { client: Custom(new JsFetchClient()) });
```

Not all variants are available on every target — unavailable cases are excluded at compile time via `#if` guards.

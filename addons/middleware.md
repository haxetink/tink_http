# Middleware

Technically, a middleware is defined as a function that takes in a [`Handler`](../basics/server.md?id=handler) and returns a new `Handler`.

In Haxe code:

```haxe
typedef Middleware = Handler->Handler;
```

## tink_http_middleware

A list of handy middleware implementations can be found in the separate library: **`tink_http_middleware`**.

!> This section is incomplete, contribute using the button at the bottom of the page

# Middleware

Technically, a middleware is defined as a function that takes in an [`Handler`](http://localhost:3000/#/basics/server?id=handler) and returns a new `Handler`.

In Haxe code:

```haxe
typedef Middleware = Handler->Handler;
```

!> This section is incomplete, contribute using the button at the bottom of the page

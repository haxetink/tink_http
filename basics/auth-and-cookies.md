# Auth and Cookies

## Reading cookies (server)

On incoming requests, use `IncomingRequestHeader`:

```haxe
switch req.header.getCookie('sessionId') {
  case null: /* no cookie */
  case value: trace(value);
}

for (name in req.header.cookieNames())
  trace(name, req.header.getCookie(name));
```

## Reading authorization (server)

```haxe
switch req.header.getAuth() {
  case Success(Basic(user, pass)): trace('basic', user);
  case Success(Bearer(token)): trace('bearer', token);
  case Success(Others(scheme, param)): trace(scheme, param);
  case Failure(e): /* no or invalid Authorization header */
}
```

`getAuth()` parses the `Authorization` header into an `Authorization` enum:

```haxe
enum Authorization {
  Basic(user:String, pass:String);
  Bearer(token:String);
  Others(scheme:String, param:String);
}
```

Use `getAuthWith(parser)` for custom auth schemes.

## Sending authorization (client)

Credentials in the URL are extracted automatically by `OutgoingRequestHeader`:

```haxe
new OutgoingRequestHeader(GET, 'http://user:pass@localhost:8080/secret');
// adds Authorization: Basic ... and strips auth from the URL
```

Or set the header explicitly:

```haxe
new OutgoingRequestHeader(GET, 'http://localhost:8080', HTTP1_1, [
  new HeaderField(AUTHORIZATION, HeaderValue.basicAuth('user', 'pass')),
]);
```

## Setting cookies (server)

Use `HeaderField.setCookie()` on response headers. Cookies are **HttpOnly by default** unless `scriptable: true` is passed:

```haxe
new ResponseHeader(OK, [
  HeaderField.setCookie('sessionId', 'abc123', { path: '/', secure: true }),
]);
```

Options: `expires`, `domain`, `path`, `secure`, `scriptable`.

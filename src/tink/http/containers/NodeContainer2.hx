#if hxnodejs_http2
package tink.http.containers;

import js.node.Https.HttpsCreateServerOptions;
import js.node.Http2.Http2ServerResponse;
import js.node.Http2.Http2ServerRequest;
import tink.http.Container;
import tink.http.Request;
import tink.http.Header;
import tink.io.*;
import js.node.http.*;
import #if haxe4 js.lib.Error #else js.Error #end as JsError;

using tink.CoreApi;

class NodeContainer2 implements Container {
	var upgradable:Bool;
	var kind:ServerKind;

	public function new(kind:ServerKind) {
		this.kind = kind;
	}

	static public function toNodeHandler(handler:Handler, ?options:{?body:Http2ServerRequest->IncomingRequestBody}) {
		var body = switch options {
			case null | {body: null}: function(msg:Http2ServerRequest) return
					Plain(Source.ofNodeStream('Incoming HTTP message from ${(msg.socket : Dynamic).remoteEndpoint}', msg.stream));
			case _: options.body;
		}
		return function(req:Http2ServerRequest,
				res:Http2ServerResponse) handler.process(new IncomingRequest((req.socket : Dynamic).remoteAddress,
				IncomingRequestHeader.fromIncomingMessage((req : Dynamic)), body(req)))
			.handle(function(out) {
				var headers = new Map();
				for (h in out.header) {
					if (!headers.exists(h.name))
						headers[h.name] = [];
					headers[h.name].push(h.value);
				}
				for (name in headers.keys())
					res.setHeader(name, headers[name]);
				res.writeHead(out.header.statusCode, out.header.reason); // TODO: readable status code
				out.body.pipeTo(Sink.ofNodeStream('Outgoing HTTP response to ${(req.socket : Dynamic).remoteAddress}', res.stream)).handle(function(x) {
					res.end();
				});
			});
	}

	public function runSecure(?cfg:Null<js.node.Http2.SecureServerOptions>, handler:Handler)
		return Future.async(function(cb) {
			var failures = Signal.trigger();
			var createServer = if (cfg == null) () -> js.node.Http2.createSecureServer()
		else
			() -> js.node.Http2.createSecureServer(cfg);
			boot(cast createServer, failures, handler).handle(cb);
		});

	public function runWithOptions(?cfg:Null<js.node.Http2.ServerOptions>, handler:Handler)
		return Future.async(function(cb) {
			var failures = Signal.trigger();
			var createServer = if (cfg == null) () -> js.node.Http2.createServer()
		else
			() -> js.node.Http2.createServer(cfg);
			boot(cast createServer, failures, handler).handle(cb);
		});

	public function run(handler:Handler)
		return Future.async(function(cb) {
			var failures = Signal.trigger();
			var createServer = () -> js.node.Http2.createServer();
			boot(cast createServer, failures, handler).handle(cb);
		});

	function boot(createServer:Void->ServerLike, failures:Signal<ContainerFailure>, handler:Handler)
		return Future.async(function(cb) {
			var server:ServerLike = switch kind {
				case Instance(server):
					server;
				case Port(port):
					var server = createServer();
					server.listen(port);
					server;
				case Host(host):
					var server = createServer();
					server.listen('${host.name}:${host.port}');
					server;
				case Path(path):
					var server = createServer();
					server.listen(path);
					server;
				case Fd(fd):
					var server = createServer();
					server.listen(fd);
					server;
			}
			server.on('error', function(e) {
				cb(Failed(e));
			});
			function onListen() {
				cb(Running({
					shutdown: function(hard:Bool) {
						if (hard)
							trace('Warning: hard shutdown not implemented');

						return Future.async(function(cb) {
							server.close(function() cb(true));
						});
					},
					failures: failures, // TODO: these need to be triggered
				}));
			}
			if (untyped server.listening) // .listening added in v5.7.0, not added to hxnodejs yet
				onListen()
			else
				server.on('listening', onListen);
			server.on('request', toNodeHandler(handler));
			server.on('error', function(e) cb(Failed(e)));
		});
}

typedef ServerLike = {
	var listening(default, null):Bool;
	function listen(i:Dynamic, ?cb:Null<Void->Void>):Void;
	function on(type:String, cb:haxe.Constraints.Function):Void;
	function close(cb:() -> Void):Void;
}

private enum ServerKindBase {
	Instance(server:ServerLike);
	Port(port:Int);
	Host(host:tink.url.Host);
	Path(path:String);
	Fd(fd:{fd:Int});
}

abstract ServerKind(ServerKindBase) from ServerKindBase to ServerKindBase {
	@:from
	public static inline function fromInstance(server:ServerLike):ServerKind
		return Instance(server);

	@:from
	public static inline function fromPort(port:Int):ServerKind
		return Port(port);

	@:from
	public static inline function fromHost(host:tink.url.Host):ServerKind
		return Host(host);

	@:from
	public static inline function fromPath(path:String):ServerKind
		return Path(path);

	@:from
	public static inline function fromFd(fd:{fd:Int}):ServerKind
		return Fd(fd);
}

#end
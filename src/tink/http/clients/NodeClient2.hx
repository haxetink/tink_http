#if hxnodejs_http2
package tink.http.clients;

import js.node.http2.Session.ClientHttp2Session;
import haxe.DynamicAccess;
import tink.io.Source;
import tink.io.Sink;
import tink.http.Client;
import tink.http.Header;
import tink.http.Request;
import tink.http.Response;
import js.node.http.IncomingMessage;
import js.node.Http2;
import js.node.http2.Session;

using tink.CoreApi;

class NodeClient2 implements ClientObject {
	var opts:js.node.Http2.SecureClientSessionOptions;
	var agent:ClientHttp2Session;

	public function new(url:tink.Url, ?opts) {
		this.opts = opts;
		this.agent = js.node.Http2.connect('${url.scheme}://${url.host}', opts);
	}

	public function request(req:OutgoingRequest):Promise<IncomingResponse> {
		var headers = {
			var map = new OutgoingHttpHeaders();
			map[":path"] = [req.header.url.pathWithQuery];
			map[":method"] = [req.header.method];
			for (h in req.header)
				map[h.name] = [h.value];
			map;
		}

		return nodeRequest(headers, req);
	}

	function nodeRequest(headers:IncomingHttpHeaders, req:OutgoingRequest):Promise<IncomingResponse>
		return Future.async(function(cb) {
			var fwd:js.node.http2.Stream.Http2Stream = agent.request(headers, {endStream: false});
			fwd.on('response', function(headers:IncomingHttpHeaders, _) {
				var status = headers[":status"];
				if (status.length < 0)
					cb(Failure(new Error('Missing status code')));
				else {
					var code = Std.parseInt(status);
					cb(Success(new IncomingResponse(new ResponseHeader(code, null, [
						for (key in headers.keys())
							new HeaderField(key, headers[key])
					], HTTP2), Source.ofNodeStream('Response from ${req.header.url}', fwd))));
				}
			});
			function fail(e:Error)
				cb(Failure(e));
			fwd.on('error', function(e:#if haxe4 js.lib.Error #else js.Error #end) fail(Error.withData(e.message, e)));
			fwd.on('end', () -> {
				agent.close();
			});
			req.body.pipeTo(Sink.ofNodeStream('Request to ${req.header.url}', fwd)).handle(function(res) {
				trace('done');
				fwd.end();
				switch res {
					case AllWritten:
					case SinkEnded(_):
						fail(new Error(502, 'Gateway Error'));
					case SinkFailed(e, _):
						fail(e);
				}
			});
		});
}
#end
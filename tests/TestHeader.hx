package;

import tink.http.Version;
import tink.http.Method;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.unit.Assert.assert;
import tink.Url;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestHeader {
	public function new() {}
	
	@:describe('Build Outgoing Request Header')
	@:variant(GET, 'https://www.example.com', HTTP1_1, [], 'GET / HTTP/1.1\r\n\r\n\r\n')
	@:variant(GET, 'https://www.example.com', HTTP2, [new tink.http.Header.HeaderField('host', 'v')], 'GET / HTTP/2\r\nhost: v\r\n\r\n')
	public function buildOutgoingRequestHeader(method:Method, url:Url, version:Version, fields:Array<HeaderField>, str:String) {
		var header = new OutgoingRequestHeader(method, url, version, fields);
		return assert(header.toString() == str);
	}
	
	// @:include
	// @:variant(GET, 'https://www.example.com', '1.1', [], 'GET https://www.example.com HTTP/1.1\r\n\r\n\r\n')
	// @:variant(GET, 'https://www.example.com', '2', [new tink.http.Header.HeaderField('host', 'v')], 'GET https://www.example.com HTTP/2\r\nhost: v\r\n\r\n')
	// public function buildOutgoingResponseHeader(method:Method, url:Url, version:String, fields:Array<HeaderField>, str:String) {
	// 	var header = new OutgoingResponseHeader()
	// 	return assert(header.toString() == str);
	// }
	
	@:describe('Parse Incoming Request Header')
	public function parseIncomingRequestHeader() {
		var req:IdealSource = 'GET /path HTTP/1.1\r\nHost: www.example.com\r\nUser-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5 (.NET CLR 3.5.30729)\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nAccept-Language: en-us,en;q=0.5\r\nAccept-Encoding: gzip,deflate\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\nKeep-Alive: 300\r\nConnection: keep-alive\r\nCookie: PHPSESSID=r2t5uvjq435r4q7ib3vtdjq120\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\nabc';
		
		return req.parse(IncomingRequestHeader.parser())
			.next(function(o) {
				var header = o.a;
				var body = o.b;
				asserts.assert(header.method == GET);
				asserts.assert(header.url == '/path');
				asserts.assert(header.version == 'HTTP/1.1');
				
				function checkHeader(name:String, value:String, ?pos:haxe.PosInfos) {
					switch header.byName(name) {
						case Success(v): asserts.assert(v == value, '$name: $value', pos);
						case Failure(e): asserts.fail(e, pos);
					}
				}
				checkHeader('host', 'www.example.com');
				checkHeader('user-agent', 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5 (.NET CLR 3.5.30729)');
				checkHeader('accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
				checkHeader('accept-language', 'en-us,en;q=0.5');
				checkHeader('accept-encoding', 'gzip,deflate');
				checkHeader('keep-alive', '300');
				checkHeader('connection', 'keep-alive');
				checkHeader('pragma', 'no-cache');
				checkHeader('cache-control', 'no-cache');
				
				asserts.assert(!header.byName('content-length').isSuccess());
				
				return body.all().next(function(c) {
					asserts.assert(c.toString() == 'abc');
					return asserts.done();
				});
			});
	}
	
	@:variant(new tink.http.Header([]), tink.http.Header)
	@:variant(new tink.http.Request.RequestHeader(GET, '', []), tink.http.Request.RequestHeader)
	@:variant(new tink.http.Request.IncomingRequestHeader(GET, '', []), tink.http.Request.IncomingRequestHeader)
	@:variant(new tink.http.Request.OutgoingRequestHeader(GET, '', []), tink.http.Request.OutgoingRequestHeader)
	@:variant(new tink.http.Response.ResponseHeader(200, 'OK', []), tink.http.Response.ResponseHeader)
	public function concat(header:Header, cls:Class<Header>) {
		var header = header.concat([new HeaderField('host', 'haxetink.org')]);
		asserts.assert(Std.is(header, cls));
		asserts.assert(Lambda.count(header) == 1);
		return asserts.done();
	}
}
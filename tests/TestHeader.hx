package;

import tink.http.Protocol;
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
	
	#if (cpp && (haxe_ver >= 4))
		// https://github.com/HaxeFoundation/haxe/issues/7536
	#else
	@:describe('Build Outgoing Request Header')
	@:variant(GET, 'https://www.example.com', HTTP1_1, [], 'GET / HTTP/1.1\r\n\r\n\r\n')
	@:variant(GET, 'https://www.example.com', HTTP2, [new tink.http.Header.HeaderField('host', 'v')], 'GET / HTTP/2\r\nhost: v\r\n\r\n')
	public function buildOutgoingRequestHeader(method:Method, url:Url, version:Protocol, fields:Array<HeaderField>, str:String) {
		var header = new OutgoingRequestHeader(method, url, version, fields);
		return assert(header.toString() == str);
	}
	#end
	
	@:variant(200, 'OK', HTTP1_1, [], 'HTTP/1.1 200 OK\r\n\r\n\r\n')
	@:variant(403, 'Forbidden', HTTP2, [new tink.http.Header.HeaderField('content-length', '0')], 'HTTP/2 403 Forbidden\r\ncontent-length: 0\r\n\r\n')
	public function buildResponseHeader(code:Int, reason:String, version:Protocol, fields:Array<HeaderField>, str:String) {
		var header = new ResponseHeader(code, reason, fields, version);
		return assert(header.toString() == str);
	}
	
	@:exclude
	@:describe('Parse Incoming Request Header')
	public function parseIncomingRequestHeader() {
		var req:IdealSource = 'GET /path HTTP/1.1\r\nHost: www.example.com\r\nUser-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5 (.NET CLR 3.5.30729)\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nAccept-Language: en-us,en;q=0.5\r\nAccept-Encoding: gzip,deflate\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\nKeep-Alive: 300\r\nConnection: keep-alive\r\nCookie: PHPSESSID=r2t5uvjq435r4q7ib3vtdjq120\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\nabc';
		
		return req.parse(IncomingRequestHeader.parser())
			.next(function(o) {
				var header = o.a;
				var body = o.b;
				asserts.assert(header.method == GET);
				asserts.assert(header.url.toString() == '/path');
				asserts.assert(header.protocol == 'HTTP/1.1');
				
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
	
	@:exclude
	@:describe('Parse Incoming Response Header')
	public function parseIncomingResponseHeader() {
		var req:IdealSource = 'HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nDate: Sat, 28 Nov 2009 04:36:25 GMT\r\nServer: LiteSpeed\r\nConnection: close\r\nX-Powered-By: W3 Total Cache/0.8\r\nPragma: public\r\nExpires: Sat, 28 Nov 2009 05:36:25 GMT\r\nEtag: "pub1259380237;gz"\r\nCache-Control: max-age=3600, public\r\nContent-Type: text/html; charset=UTF-8\r\nLast-Modified: Sat, 28 Nov 2009 03:50:37 GMT\r\nX-Pingback: http://net.tutsplus.com/xmlrpc.php\r\nContent-Encoding: gzip\r\nVary: Accept-Encoding, Cookie, User-Agent\r\n\r\nabc';
		
		return req.parse(ResponseHeader.parser())
			.next(function(o) {
				var header = o.a;
				var body = o.b;
				asserts.assert(header.protocol == HTTP1_1);
				asserts.assert(header.statusCode == StatusCode.OK);
				asserts.assert(header.reason == StatusCode.OK);
				
				function checkHeader(name:String, value:String, ?pos:haxe.PosInfos) {
					switch header.byName(name) {
						case Success(v): asserts.assert(v == value, '$name: $value', pos);
						case Failure(e): asserts.fail(e, pos);
					}
				}
				checkHeader('Transfer-Encoding', 'chunked');
				checkHeader('Date', 'Sat, 28 Nov 2009 04:36:25 GMT');
				checkHeader('Server', 'LiteSpeed');
				checkHeader('Connection', 'close');
				checkHeader('X-Powered-By', 'W3 Total Cache/0.8');
				checkHeader('Pragma', 'public');
				checkHeader('Expires', 'Sat, 28 Nov 2009 05:36:25 GMT');
				checkHeader('Etag', '"pub1259380237;gz"');
				checkHeader('Cache-Control', 'max-age=3600, public');
				checkHeader('Content-Type', 'text/html; charset=UTF-8');
				checkHeader('Last-Modified', 'Sat, 28 Nov 2009 03:50:37 GMT');
				checkHeader('X-Pingback', 'http://net.tutsplus.com/xmlrpc.php');
				checkHeader('Content-Encoding', 'gzip');
				checkHeader('Vary', 'Accept-Encoding, Cookie, User-Agent');
				
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
	@:variant(new tink.http.Response.ResponseHeader(200, 'OK', []), tink.http.Response.ResponseHeaderBase)
	public function concat(header:Header, cls:Class<Header>) {
		var header = header.concat([new HeaderField('host', 'haxetink.org')]);
		asserts.assert(Std.is(header, cls));
		asserts.assert(Lambda.count(header) == 1);
		return asserts.done();
	}
	
	function createAuthHeader(v)
		return new IncomingRequestHeader(GET, '/', [new HeaderField(AUTHORIZATION, v)]);
	
	@:variant('Basic aGF4ZTp0aW5r', Basic('haxe', 'tink'))
	@:variant('Bearer my_token', Bearer('my_token'))
	@:variant('Haxe haxe_token', Others('Haxe', 'haxe_token'))
	public function getAuth(auth:String, expected:Authorization)
		return assert(Type.enumEq(createAuthHeader(auth).getAuth(), Success(expected)));
		
	@:variant('Basic abc')
	@:variant('Basic')
	public function getAuthError(auth:String)
		return assert(!createAuthHeader(auth).getAuth().isSuccess());
		
	function createContentLengthHeader(v)
		return new Header([new HeaderField(CONTENT_LENGTH, v)]);
			
	@:variant('1', 1)
	@:variant('2', 2)
	public function getContentLength(v:String, expected:Int)
		return assert(Type.enumEq(createContentLengthHeader(v).getContentLength(), Success(expected)));
		
	@:variant('v')
	public function getContentLengthError(v:String)
		return assert(!createContentLengthHeader(v).getContentLength().isSuccess());
		
	public function getMissingContentLength()
		return assert(new Header().getContentLength().match(Failure(_)));
		
	@:variant('text/plain, text/html', 'text/plain', true)
	@:variant('text/plain, text/html', 'text/html', true)
	@:variant('text/*, application/json', 'text/html', true)
	@:variant('*/*, application/json', 'text/html', true)
	@:variant('application/json, text/*', 'text/html', true)
	@:variant('application/json, */*', 'text/html', true)
	@:variant('text/x-dvi; q=.8; mxb=100000; mxt=5.0, text/x-c', 'text/plain', false)
	@:variant('text/*', 'application/json', false)
	public function accepts(header:String, type:String, accepted:Bool)
		return assert(new Header([new HeaderField(ACCEPT, header)]).accepts(type).sure() == accepted);
		
	@:variant('foo', 'bar', 'Basic Zm9vOmJhcg==')
	public function basicAuth(username:String, password:String, output:String)
		return assert(HeaderValue.basicAuth(username, password) == output);
}
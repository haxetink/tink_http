package;

import tink.http.Method;
import tink.http.Request;

using tink.io.Source;
using tink.CoreApi;

@:asserts
class TestHeader {
	public function new() {}
	
	public function parse() {
		var req:IdealSource = 'GET /path HTTP/1.1\r\nHost: www.example.com\r\nUser-Agent: Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.1.5) Gecko/20091102 Firefox/3.5.5 (.NET CLR 3.5.30729)\r\nAccept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r\nAccept-Language: en-us,en;q=0.5\r\nAccept-Encoding: gzip,deflate\r\nAccept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7\r\nKeep-Alive: 300\r\nConnection: keep-alive\r\nCookie: PHPSESSID=r2t5uvjq435r4q7ib3vtdjq120\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\nabc';
		
		return req.parse(IncomingRequestHeader.parser())
			.next(function(o) {
				var header = o.a;
				var body = o.b;
				asserts.assert(header.method == GET);
				asserts.assert(header.url == '/path');
				asserts.assert(header.version == 'HTTP/1.1');
				asserts.assert(header.byName('host').sure() == 'www.example.com');
				asserts.assert(!header.byName('content-length').isSuccess());
				return body.all().next(function(c) {
					asserts.assert(c.toString() == 'abc');
					return asserts.done();
				});
			});
	}
}
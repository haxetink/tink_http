package;

import haxe.unit.TestCase;
import tink.http.Cookie;

class TestCookie extends TestCase {
	function testCookie() {
		var cookies = Cookie.parse('name=value');
		assertEquals(1, cookies.length);
		assertEquals('name', cookies[0].name);
		assertEquals('value', cookies[0].value);
		
		var cookies = Cookie.parse('name=value; name1=value1');
		assertEquals(2, cookies.length);
		assertEquals('name', cookies[0].name);
		assertEquals('value', cookies[0].value);
		assertEquals('name1', cookies[1].name);
		assertEquals('value1', cookies[1].value);
		
		var cookie = new Cookie('name', 'value');
		assertEquals('name=value', cookie);
		
		var cookie = new Cookie('name', 'value', DateTools.delta(Date.now(), 1000));
		trace((cookie:String)); // TODO: assert time zone
		
		var cookie = new Cookie('name', 'value', 'domain.com', '/path');
		assertEquals('name=value; domain=domain.com; path=/path', cookie);
		
		var cookie = new Cookie('name', 'value', 'domain.com', '/path', true, true);
		assertEquals('name=value; domain=domain.com; path=/path; secure; httponly', cookie);
	}
}
package tink.http;

@:enum
abstract Protocol(String) from String to String {
	var HTTP1_0 = 'HTTP/1.0';
	var HTTP1_1 = 'HTTP/1.1';
	var HTTP2 = 'HTTP/2';
}
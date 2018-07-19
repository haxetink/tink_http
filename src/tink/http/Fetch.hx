package tink.http;

import haxe.io.Bytes;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Method;
import tink.http.Client;
import tink.http.clients.*;
import tink.url.Host;
import tink.io.Worker;
import tink.Url;
import tink.Chunk;
import tink.Anon.*;

using tink.io.Source;
using tink.CoreApi;

class Fetch {
	
	static var client = new Map<ClientType, Client>();
	static var sclient = new Map<ClientType, Client>();
	
	public static function fetch(url:Url, ?options:FetchOptions):FetchResponse {
		
		return Future.async(function(cb) {
			
			var uri:String = url.path;
			if(url.query != null) uri += '?' + url.query;
			
			var method = GET;
			var headers = null;
			var body:IdealSource = Source.EMPTY;
			var type = Default;
			var followRedirect = true;
			
			if(options != null) {
				if(options.method != null) method = options.method;
				if(options.headers != null) headers = options.headers;
				if(options.body != null) body = options.body;
				if(options.client != null) type = options.client; 
				if(options.followRedirect == false) followRedirect = false; 
			}
			
			var client = getClient(type, url.scheme == 'https');
			client.request(new OutgoingRequest(
				new OutgoingRequestHeader(method, url, headers),
				body
			)).handle(function(res) {
				switch res {
					case Success(res):
						switch res.header.statusCode {
							case code = 301 | 302 | 303 | 307 | 308 if(followRedirect): 
								Promise.lift(res.header.byName('location'))
									.next(function(location) return fetch(url.resolve(location), code == 303 ? merge(options, method = GET) : options))
									.handle(cb);
							default: cb(Success(res));
						}
					case Failure(e):
						cb(Failure(e));
				}
			});
		});
	}
	
	static function getClient(type:ClientType, secure:Bool) {
		var cache = secure ? sclient : client;
		
		if(!cache.exists(type)) {
			
			var c:Client = switch type {
				case Default:
					if(secure)
						#if (js && !nodejs) new SecureJsClient()
						#elseif nodejs new SecureNodeClient()
						#elseif sys new SecureSocketClient()
						#end
					else 
						#if (js && !nodejs) new JsClient()
						#elseif nodejs new NodeClient()
						#elseif sys new SocketClient()
						#end ;
				case Local(c): new LocalContainerClient(c);
				case Curl: secure ? new SecureCurlClient() : new CurlClient();
				case StdLib: secure ? new SecureStdClient() : new StdClient();
				#if php case Php: secure ? new SecurePhpClient() : new PhpClient(); #end
				// #if (js || php) case Std: secure ? new SecureStdClient() : new StdClient(); #end
				#if tink_tcp case Tcp: secure ? new SecureTcpClient() : new TcpClient(); #end
				#if flash case Flash: secure ? new SecureFlashClient() : new FlashClient(); #end
				#if openfl case OpenFl: secure ? new SecureFlashClient() : new FlashClient(); #end
			}
			
			
			cache.set(type, c);
		}
		
		return cache.get(type);
		
	}
}

typedef FetchOptions = {
	?method:Method,
	?headers:Array<HeaderField>,
	?body:IdealSource,
	?client:ClientType,
	?followRedirect:Bool,
}

enum ClientType {
	Default;
	Local(container:tink.http.containers.LocalContainer);
	Curl;
	StdLib;
	#if php Php; #end
	#if tink_tcp Tcp; #end
	#if flash Flash; #end
	#if openfl OpenFl; #end
}

@:forward
abstract FetchResponse(Promise<IncomingResponse>) from Surprise<IncomingResponse, Error> to Surprise<IncomingResponse, Error> from Promise<IncomingResponse> to Promise<IncomingResponse> {
	public function all():Promise<CompleteResponse> {
		return this
			.next(function(r) {
				return r.body.all()
					.next(function(chunk) return new CompleteResponse(r.header, chunk));
			});
	}
}

typedef CompleteResponse = Message<ResponseHeader, Chunk>;
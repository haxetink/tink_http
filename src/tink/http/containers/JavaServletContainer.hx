package tink.http.containers;

import java.javax.servlet.http.*;
import java.io.*;
import tink.http.Container;
import tink.http.Request;
import tink.http.Header;
import tink.io.Source;
import tink.io.Sink;
import tink.io.java.*;

using tink.CoreApi;

/**
	How to use:
	
	1. Write some haxe code as follow:
	
	```haxe
	package;

	import java.javax.servlet.http.*;
	import tink.http.containers.JavaServletContainer;
	import tink.http.Request;
	import tink.http.Response;
	using tink.CoreApi;

	class Main extends HttpServlet {	
		@:overload
		override function service(req:HttpServletRequest, res:HttpServletResponse) {
			return JavaServletContainer.toServletHandler(handle)(req, res);
		}
		
		function handle(req:IncomingRequest):Future<OutgoingResponse>
			return Future.sync(('Done':OutgoingResponse));
	}
	```
	
	2. Add the following xml to web.xml, put them inside the <web-app> tag, leaving other entries intact.
	
	```xml
	<servlet>
		<servlet-name>Main</servlet-name>
		<servlet-class>haxe.root.Main</servlet-class>
	</servlet>

	<servlet-mapping>
		<servlet-name>Main</servlet-name>
		<url-pattern>/</url-pattern>
	</servlet-mapping>
	```
	
	3. Start you Servlet container (e.g. Tomcat) and use a browser navigate to the default address (e.g. localhost:8080)
	
**/

class JavaServletContainer {
	
	static public function toServletHandler(handler:Handler)
		return 
			function (req:HttpServletRequest, res:HttpServletResponse)
				handler.process(
					new IncomingRequest(
						req.getRemoteAddr(),
						new IncomingRequestHeader(
							cast req.getMethod(), 
							req.getRequestURI() + switch req.getQueryString() {
								case null: '';
								case v: '?$v';
							},
							req.getProtocol(),
							{
								var names = req.getHeaderNames();
								var headers = [];
								while(names.hasMoreElements()) {
									var name = names.nextElement();
									var values = req.getHeaders(name);
									while(values.hasMoreElements()) headers.push(new HeaderField(name, values.nextElement()));
								}
								headers;
							}
						),
						Plain(Source.ofInput('Incoming HTTP message from ${req.getRemoteAddr()}', new NativeInput(req.getInputStream())))
					)
				).handle(function (out) {
					res.setStatus(out.header.statusCode);
					for(header in out.header.fields) res.addHeader(header.name, header.value);
					out.body.pipeTo(Sink.ofOutput('Outgoing HTTP response to ${req.getRemoteAddr()}', new NativeOutput(res.getOutputStream()))).handle(function (x) {
						// res.getOutputStream().flush();
					});
				});
}

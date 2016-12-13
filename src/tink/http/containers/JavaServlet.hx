package tink.http.containers;

import java.javax.servlet.http.*;
import java.io.*;
import tink.http.Container;
import tink.http.Request;
import tink.http.Response;
import tink.http.Header;
import tink.http.Handler;
import tink.io.Source;
import tink.io.Sink;
import tink.io.java.*;

using tink.CoreApi;

/**
	Example usage (with Tomcat):
	
	1. Write some haxe code as follow:
		
		```haxe
		package;

		import tink.http.containers.*;
		import tink.http.Request;
		import tink.http.Response;
		using tink.CoreApi;

		class Main extends JavaServlet {
			override function process(req:IncomingRequest):Future<OutgoingResponse>
				return Future.sync(('Hello, World!':OutgoingResponse));
		}
		```
	
	2. Compile with `haxe Main -java bin/java -java-lib path/to/servlet-api.jar -lib tink_http`.
	   Don't put `-main` otherwise the compiler will complain for a missing entry point,
	   Move the everything under `bin/java/obj` to where your Servlet Container serves.
	   For Tomcat it will be `<tomcat installation path>/webapps/ROOT/WEB-INF/classes`
	   (So you should have `<tomcat installation path>/webapps/ROOT/WEB-INF/classes/haxe/root/Main.class`)
	
	2. Add the following xml to web.xml.
	   Put them inside the <web-app> tag, leaving other entries intact.
	   For Tomcat `web.xml` should be located at `<tomcat installation path>/webapps/ROOT/WEB-INF/`
	
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
	
	3. Start you Servlet container and use a browser navigate to the default address
	   For Tomcat, run `<tomcat installation path>/bin/startup.sh` (or `startup.bat`)
	   and then visit `localhost:8080`
	
**/

class JavaServlet extends HttpServlet implements HandlerObject {
	
	@:overload
	override function service(req:HttpServletRequest, res:HttpServletResponse) {
		process(
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
	
	public function process(req:IncomingRequest):Future<OutgoingResponse> {
		return Future.sync(('Done':OutgoingResponse));
	}
}

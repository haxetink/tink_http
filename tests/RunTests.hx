package;

import haxe.CallStack;

class RunTests {
	
	public static var port = 8000;
	
	#if !neko
	
	public static function main() {}
	
	#else
	
	public static function main() {
		var result = false;
		try {
			var args = [
				'-lib', 'tink_http', '-cp', 'tests', '-lib', 'buddy',
				'-D', 'server='+server(),
				'-D', 'client='+client(),
			];
			Server.compile(args);
			Client.compile(args);
			try {
				Server.start(port);
				waitForConnection(port);
				result = Client.run();
				Server.stop();
			} catch(e: Dynamic) {
				Sys.println(e);
				Sys.print(CallStack.toString(CallStack.exceptionStack()));
			}
		} catch(e: Dynamic) {}
		Sys.sleep(.01);
		Sys.exit(result ? 0 : 1);
	}
	
	static function waitForConnection(port: Int) {
		var i = 0;
		while (i < 20) {
			var http = new haxe.Http('http://127.0.0.1:'+port+'/active');
			var result = false;
			http.onData = function(_)
				result = true;
			http.request();
			if (result) return;
			else Sys.sleep(.1);
		}
		throw 'Could not connect to server';
	}
	
	// Stop compiling on other targets so dependencies can easily be installed through travix
	public static function haltCompiler()
		if (Sys.args().filter(function(arg) return arg == '-neko').length == 0)
			Sys.exit(0);
	
	macro static function server() 
		return macro $v{haxe.macro.Context.definedValue('server')};
		
	macro static function client() 
		return macro $v{haxe.macro.Context.definedValue('client')};
	
	#end
	
}
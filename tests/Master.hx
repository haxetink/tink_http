package;

import haxe.CallStack;
import sys.net.Host;
import sys.net.Socket;
import sys.io.File;

using tink.CoreApi;

@:await
class Master {
	
	public static var port = 8000;
	static var originalHxml:String;
	
	@:await
	public static function main() {
		checkPort(port);
		originalHxml = File.getContent('tests.hxml');
		
		var containers: String = Env.getDefine('containers');
		if (containers == null)
			fail('No containers set, use -D containers=php,neko');
		var targets: String = Env.getDefine('targets');
		if (targets == null)
			fail('No targets set, use -D targets=php,neko');
		
		var result = true;
		for(container in containers.split(',')) {
			
			if (!Context.containers.exists(container))
				fail('Container $container not available');
				
			var server = Context.containers.get(container);

			try {
				Sys.println(Ansi.text(Cyan, '\n>> Building container $container'));
				var process = server(port);
				@:await waitForConnection(port).next(function(_) {
					for (target in targets.split(',')) {
						if (!Context.targets.exists(target)) {
							Ansi.fail('No such target: $target');
							continue;
						}
						Sys.println(Ansi.text(Yellow, '\n>> Running target $target'));
						var runner = Context.targets.get(target)(port);
						var code = runner.exitCode();
						if (code != 0)
							Ansi.fail('$target failed');
						result = result && code == 0;
						if (!result) break;
					}
					
					close(port);
					process.kill();
					return Noise;
				});
				
			}
		}
		restoreHxml();
		Sys.exit(result ? 0 : 1);
		
	}
	
	static function restoreHxml() {
		if(originalHxml != null) File.saveContent('tests.hxml', originalHxml);
	}

	static function fail(msg) {
		Ansi.fail(msg);
		restoreHxml();
		Sys.exit(1);
	}

	static function close(port: Int) {
		var http = new haxe.Http('http://127.0.0.1:$port/close');
		http.onData = function(_) null;
		http.request();
	}
	
	static function waitForConnection(port: Int) {
		Sys.println('Waiting for server to be ready...');
		return Future.async(function(cb) {
			var retry = 10;
			var delay = 100;

			function next() {
				var http = new haxe.Http('http://127.0.0.1:'+port+'/active');
				var result = false;
				http.onData = function(_) {
					Sys.println('Server ready');
					cb(true);
				}
				http.onError = function(_) {
					if(retry-- == 0) {
						fail('Server not ready');
						cb(false);
					} else {
						haxe.Timer.delay(next, delay *= 2);
					}
				}
				http.request();
			}
			next();
		});
	}

	static function checkPort(port: Int) {
		var socket = new Socket();
		try {
			socket.connect(new Host('127.0.0.1'), port);
			fail('Another process is already bound to port $port');
		} catch (e: Dynamic) {}
	}
	
}
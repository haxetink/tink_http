package server;

class NodeServer {
	
	#if !is_server
	
	static var server;

	public static function compile(args) {
		ProcessTools.install('node');
		ProcessTools.compile(args.concat([
			'-D', 'is_server',
			'-lib', 'hxnodejs',
			'-main', 'DummyServer',
			'-js', 'bin/node/index.js'
		]));
	}
	
	public static function start(port: Int) {
		server = ProcessTools.streamAll('node', ['bin/node/index.js', '$port']);
	}
	
	public static function stop()
		server.kill();
	
	#else
	
	public static function main() {
		var container = new tink.http.containers.NodeContainer(Std.parseInt(Sys.args()[0]));
		container.run(DummyServer.handleRequest);
	}
	
	#end
	
}
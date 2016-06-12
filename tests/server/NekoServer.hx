package server;

import sys.io.Process;

class NekoServer {
	
	#if !is_server
	
	static var server: Process;	

	public static function compile(args)
		ProcessTools.compile(args.concat([
			'-D', 'is_server',
			'-lib', 'tink_tcp',
			'-lib', 'tink_runloop',
			'-main', 'DummyServer',
			'-neko', 'bin/neko/index.n'
		]));
	
	public static function start(port: Int) {
		server = ProcessTools.streamAll('neko', ['bin/neko/index.n', '$port']);
	}
	
	public static function stop()
		server.kill();
		
	#else
		
	public static function main()
		TcpHandler.main();
		
	#end
	
}
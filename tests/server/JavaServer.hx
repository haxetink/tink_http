package server;

import sys.io.Process;

class JavaServer {
	
	#if neko
	
	static var server: Process;

	public static function compile(args) {
		ProcessTools.install('java');
		ProcessTools.compile(args.concat([
			'-D', 'is_server',
			'-D', 'concurrent',
			'-lib', 'tink_tcp',
			'-lib', 'tink_runloop',
			'-main', 'DummyServer',
			'-java', 'bin/java'
		]));
	}
	
	public static function start(port: Int) {
		server = ProcessTools.streamAll('java', ['-jar', 'bin/java/DummyServer.jar', '$port']);
	}
	
	public static function stop()
		server.kill();
	
	#else
	
	public static function main()
		TcpHandler.main();
		
	#end
	
}
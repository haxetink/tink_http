package server;

import sys.io.Process;

class CppServer {
	
	static var server: Process;

	public static function compile(args) {
		ProcessTools.install('cpp');
		ProcessTools.compile(args.concat([
			'-D', 'is_server',
			'-D', 'concurrent',
			'-lib', 'tink_tcp',
			'-lib', 'tink_runloop',
			'-lib', 'hxcpp',
			'-main', 'DummyServer',
			'-cpp', 'bin/cpp'
		]));
	}
	
	public static function start(port: Int) {
		server = ProcessTools.streamAll('bin/cpp/DummyServer', ['$port']);
	}
	
	public static function stop()
		server.kill();
		
	public static function main()
		TcpHandler.main();
	
}
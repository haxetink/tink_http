package server;

import sys.io.Process;

class PhpServer {
	
	#if neko
	
	static var server: Process;

	public static function compile(args) {
		ProcessTools.install('php');
		ProcessTools.compile(args.concat([
			'-main', 'DummyServer',
			'-php', 'bin/php/server'
		]));
	}
	
	public static function start(port: Int)
		server = ProcessTools.streamAll('php', ['-S', '127.0.0.1:'+port, 'bin/php/server/index.php']);
	
	public static function stop()
		server.kill();
	
	#elseif php
	
	public static function main()
		tink.http.containers.PhpContainer.inst.run(DummyServer.handleRequest);
		
	#end
	
}
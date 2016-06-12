package server;

import sys.io.Process;
import tink.http.containers.ModnekoContainer;

class NekoToolsServer {
	
	static var server: Process;

	public static function compile(args)
		ProcessTools.compile(args.concat([
			'-main', 'DummyServer',
			'-neko', 'bin/neko/index.n'
		]));
	
	public static function start(port: Int) {
		var cwd = Sys.getCwd();
		Sys.setCwd('bin/neko');
		server = ProcessTools.streamAll('nekotools', ['server', '-p', '$port', '-rewrite']);
		Sys.setCwd(cwd);
	}
	
	public static function stop()
		server.kill();
	
	public static function main()
		ModnekoContainer.inst.run(DummyServer.handleRequest);
	
}
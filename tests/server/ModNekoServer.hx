package server;

import sys.io.Process;
import tink.http.containers.ModnekoContainer;

class ModNekoServer {

	public static function compile(args)
		ProcessTools.compile(args.concat([
			'-main', 'DummyServer',
			'-neko', 'bin/neko/index.n'
		]));
	
	public static function start(port: Int) {
		sys.io.File.saveContent('bin/neko/.htaccess', ['RewriteEngine On','RewriteBase /','RewriteRule ^(.*)$ index.n [QSA,L]'].join('\n'));
		Sys.command('docker', ['run', '-d', '-v', sys.FileSystem.fullPath(Sys.getCwd()+'/bin/neko')+':/var/www/html', '-p', port+':80', '--name', 'tink_http_mod_neko', 'codeurs/mod-neko']);
	}
	
	public static function stop() {
		new Process('docker', ['kill', 'tink_http_mod_neko']).exitCode();
		new Process('docker', ['rm', 'tink_http_mod_neko']).exitCode();
	}
	
	public static function main()
		ModnekoContainer.inst.run(DummyServer.handleRequest);
	
}
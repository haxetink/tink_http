package client;

import tink.http.Client;

class NekoClient {

	public static function compile(args)
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-neko', 'bin/neko/runner.n'
		]));
	
	public static function run()
		return ProcessTools.passThrough('neko', ['bin/neko/runner.n']);

	public static function getClients() {
		var clients:Array<Client> = [];
		return [new StdClient()];
	}
  
}
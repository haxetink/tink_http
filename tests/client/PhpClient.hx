package client;

import tink.http.Client;

class PhpClient {

	public static function compile(args) {
		ProcessTools.install('php');
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-php', 'bin/php/client'
		]));
	}
	
	public static function run()
		return ProcessTools.passThrough('php', ['bin/php/client/index.php']);

	public static function getClients() {
		var clients:Array<Client> = [];
		return [new StdClient()];
	}
  
}
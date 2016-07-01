package client;

import tink.http.Client;

class PhpClient {
	
	#if neko
	
	public static function compile(args) {
		ProcessTools.install('php');
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-php', 'bin/php/client'
		]));
	}
	
	public static function run()
		return ProcessTools.streamAll('php', ['bin/php/client/index.php']).exitCode() == 0;
		
	#else

	public static function getClients() {
		var clients:Array<Client> = [];
		return [
			{
				name: 'Php client',
				client: new StdClient()
			}
		];
	}
	
	#end
  
}
package client;

import tink.http.Client;

class NekoClient {

	public static function compile(args)
		ProcessTools.compile(args.concat([
			'-D', 'is_client',
			'-lib', 'tink_tcp',
			'-main', 'Runner',
			'-neko', 'bin/neko/runner.n'
		]));
	
	public static function run()
		return ProcessTools.streamAll('neko', ['bin/neko/runner.n']).exitCode() == 0;

	#if is_client
	public static function getClients() {
		var clients:Array<Client> = [];
		return [
			{
				name: 'Neko std client',
				client: new StdClient()
			}/*,
			{
				name: 'Neko tcp client',
				client: new TcpClient()
			}*/
		];
	}
	#end
  
}
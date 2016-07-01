package client;

class JavaClient {

	#if neko
	
	public static function compile(args) {
		ProcessTools.install('java');
		ProcessTools.compile(args.concat([
			'-main', 'Runner',
			'-lib', 'tink_tcp',
			'-lib', 'hxjava',
			'-java', 'bin/java'
		]));
	}
	
	public static function run()
		return ProcessTools.streamAll('java', ['-jar', 'bin/java/Runner.jar']).exitCode() == 0;
		
	#else
	
	public static function getClients() {
		var clients:Array<Client> = [];
		return [
			{
				name: 'Java Tcp client',
				client: new tink.http.Client.TcpClient()
			}
		];
	}
	
	#end
  
}
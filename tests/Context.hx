import tink.http.Handler;
import tink.http.Client;

#if neko
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

typedef ContainerInterface = Int -> {function kill(): Void;};

class Context {
  
  #if php
	static function __init__()
		untyped __call__('ini_set', 'xdebug.max_nesting_level', 100000);
	#end
  
  static inline var RUN = 'RUN_SERVER';
  
  #if neko
  
  static function mainArgs(port: Int, server: String)
    return ['-D port=$port', '-D server=$server', '-main DummyServer'];
  
  static function tcpArgs(port: Int)
    return mainArgs(port, 'tcp').concat(['-lib tink_tcp', '-lib tink_runloop', '-D concurrent']);
    
  static function tcpContainer(target: String)
    return function(port: Int)
      return ProcessTools.travix(target, tcpArgs(port));
      
  static function setEnv()
   Sys.putEnv(RUN, 'true');
   
  static function clearEnv()
   Sys.putEnv(RUN, '');
   
  static function buildModNeko(port: Int) {
    clearEnv();
    var code = ProcessTools.travix('neko', mainArgs(port, 'modneko')).exitCode();
    if (code != 0) 
      throw 'Unable to build mod neko server';
    FileSystem.rename('bin/neko/tests.n', 'bin/neko/index.n');
    setEnv();
  }
  
  public static var containers: Map<String, ContainerInterface> = [
    'php' => function(port) {
      clearEnv();
      var code = ProcessTools.travix('php', mainArgs(port, 'php')).exitCode();
      if (code != 0) 
        throw 'Unable to build php server';
      FileSystem.rename('bin/php/index.php', 'bin/php/server.php');
      setEnv();
      return ProcessTools.streamAll('php', ['-S', '127.0.0.1:'+port, 'bin/php/server.php']);
    },
    
    'neko-tools' => function(port) {
      buildModNeko(port);
      var cwd = Sys.getCwd();
      Sys.setCwd('bin/neko');
      var server = ProcessTools.streamAll('nekotools', ['server', '-p', '$port', '-rewrite']);
      Sys.setCwd(cwd);
      return server;
    },
    
    'neko-mod' => function(port) {
      buildModNeko(port);
      File.saveContent('bin/neko/.htaccess', ['RewriteEngine On','RewriteBase /','RewriteRule ^(.*)$ index.n [QSA,L]'].join('\n'));
      ProcessTools.streamAll('docker', ['run', '-d', '-v', FileSystem.fullPath(Sys.getCwd() + '/bin/neko') + ':/var/www/html', '-p', port + ':80', '--name', 'tink_http_mod_neko', 'codeurs/mod-neko']);
      return {
        kill: function() {
          new Process('docker', ['kill', 'tink_http_mod_neko']).exitCode();
          new Process('docker', ['rm', 'tink_http_mod_neko']).exitCode();
        }
      }
    },
    
    'neko' => tcpContainer('neko'),
    'java' => tcpContainer('java'),
    'cpp' => tcpContainer('cpp'),
    'node' => function(port: Int)
      return ProcessTools.travix('node', mainArgs(port, 'node'))
  ];
  
  #end
  
  public static var servers: Map<String, Int -> Handler -> Void> = [
  
    '' => null,
  
    #if php
    'php' => function (port, handler) {
      if (Sys.getEnv(RUN) != 'true') return;
      tink.http.containers.PhpContainer.inst.run(handler);
    },
    #end
    
    #if neko
    'modneko' => function (port, handler) {
      if (Sys.getEnv(RUN) != 'true') return;
      tink.http.containers.ModnekoContainer.inst.run(handler);
    },
    #end
    
    #if nodejs
    'node' => function (port, handler) 
      new tink.http.containers.NodeContainer(port).run(handler),
    #end
    
    #if (tink_tcp && tink_runloop)
    'tcp' => function (port, handler)
      @:privateAccess tink.RunLoop.create(function()
        new tink.http.containers.TcpContainer(port)
        .run(handler)
      ),
    #end
  
  ];
  
  public static var clients: Map<String, Client> = [
    
    #if (!nodejs)
    'std' => new StdClient(),
    #end
    
    #if (tink_tcp)
    'tcp' => new TcpClient(),
    #end
    
    #if nodejs
    'node' => new tink.http.Client.NodeClient(),
    #end
  
  ];
}
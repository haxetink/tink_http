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
  
  static inline var RUN = 'RUN_TRAVIS';
  
  #if neko
  
  static function mainArgs(port: Int, server: String)
    return ['-D port=$port', '-D server=$server', '-main DummyServer'];
  
  static function tcpArgs(port: Int, concurrent)
    return mainArgs(port, 'tcp').concat(['-lib tink_tcp', '-lib tink_runloop']).concat(concurrent?['-D concurrent']:[]);
    
  static function tcpContainer(target: String, concurrent: Bool = false)
    return function(port: Int)
      return ProcessTools.travix(target, tcpArgs(port, concurrent));
      
  static function setEnv()
   Sys.putEnv(RUN, '');
   
  static function clearEnv()
   Sys.putEnv(RUN, 'true');
   
  static function buildModNeko(port: Int) {
    clearEnv();
    var code = ProcessTools.travix('neko', mainArgs(port, 'modneko')).exitCode();
    if (code != 0) 
      throw 'Unable to build mod neko server';
    try
      FileSystem.deleteFile('bin/neko/index.n')
    catch(e: Dynamic) {}
    FileSystem.rename('bin/neko/tests.n', 'bin/neko/index.n');
    setEnv();
  }
  
  public static var containers: Map<String, ContainerInterface> = [
    'php' => function(port) {
      clearEnv();
      var code = ProcessTools.travix('php', mainArgs(port, 'php')).exitCode();
      if (code != 0) 
        throw 'Unable to build php server';
      try
        FileSystem.deleteFile('bin/php/server.php')
      catch(e: Dynamic) {}
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
    
    'neko' => tcpContainer('neko', true),
    'java' => tcpContainer('java', true),
    'cpp' => tcpContainer('cpp', true),
    
    'node-tcp' => function(port: Int)
      return ProcessTools.travix('node', mainArgs(port, 'tcp').concat(['-lib tink_tcp'])),
    'node' => function(port: Int)
      return ProcessTools.travix('node', mainArgs(port, 'node'))
  ];
  
  #end
  
  public static var servers: Map<String, Int -> Handler -> Void> = [
  
    '' => null,
  
    #if php
    'php' => function (port, handler) {
      if (Sys.getEnv(RUN) == 'true') return;
      tink.http.containers.PhpContainer.inst.run(handler);
    },
    #end
    
    #if neko
    'modneko' => function (port, handler) {
      if (Sys.getEnv(RUN) == 'true') return;
      tink.http.containers.ModnekoContainer.inst.run(handler);
    },
    #end
    
    #if nodejs
    'node' => function (port, handler) 
      new tink.http.containers.NodeContainer(port).run(handler),
    #end
    
    #if (tink_tcp && tink_runloop)
    'tcp' => function (port, handler)
      #if tink_runloop @:privateAccess tink.RunLoop.create(function() #end
        new tink.http.containers.TcpContainer(port)
        .run(handler)
      #if tink_runloop ) #end, 
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
    'node' => new NodeClient(),
    #end
    
    #if (neko || nodejs)
    'curl' => new CurlClient()
    #end
    
    #if (js && !nodejs)
    'js' => new JsClient()
    #end
  
  ];
  
  #if neko
  
  static function targetArgs(port: Int)
    return ['-lib buddy', '-lib deep_equal', '-D port=$port', '-main Runner'];
    
  static function travixTarget(name, port: Int)
    return ProcessTools.travix(name, targetArgs(port));
    
  static function tcpTarget(name, port: Int)
    return ProcessTools.travix(name, targetArgs(port).concat(['-lib tink_tcp']));
  
  public static var targets: Map<String, Int -> Process> = [
    'neko' => travixTarget.bind('neko'),
    'node' => travixTarget.bind('node'),
    'php' => travixTarget.bind('php'),
    'java' => travixTarget.bind('java'),
    'cpp' => travixTarget.bind('cpp'),
    'js' => travixTarget.bind('js'),
    
    'neko-tcp' => tcpTarget.bind('neko'),
  ];
  
  #end
}
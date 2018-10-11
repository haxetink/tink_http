package;

#if tink_http
import tink.http.Handler;
import tink.http.Client;
import tink.http.clients.*;
#end

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
  
  static function tcpArgs(port: Int, concurrent)
    return mainArgs(port, 'tcp').concat(['-lib tink_tcp', '-lib tink_runloop']).concat(concurrent?['-D concurrent']:[]);
    
  static function tcpContainer(target: String, concurrent: Bool = false)
    return function(port: Int)
      return ProcessTools.travix(target, tcpArgs(port, concurrent));
      
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
      var server = ProcessTools.streamAll('nekotools', ['server', '-p', '$port', '-rewrite', '-log', 'log.txt']);
      Sys.setCwd(cwd);
      return server;
    },
    
    'neko-mod' => function(port) {
      buildModNeko(port);
      File.saveContent('bin/neko/.htaccess', ['RewriteEngine On','RewriteBase /','RewriteRule ^(.*)$ index.n [QSA,L]'].join('\n'));
      ProcessTools.streamAll('docker', ['run', '-d', '-e', '$RUN=true', '-v', FileSystem.fullPath(Sys.getCwd() + '/bin/neko') + ':/var/www/html', '-p', port + ':80', '--name', 'tink_http_mod_neko', 'codeurs/mod-neko']);
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
  
  #if tink_http
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
    
    #if (tink_tcp && (nodejs || tink_runloop))
    'tcp' => function (port, handler)
      #if tink_runloop @:privateAccess tink.RunLoop.create(function() #end
        new tink.http.containers.TcpContainer(
          #if nodejs
            tink.tcp.nodejs.NodejsAcceptor.inst.bind.bind(port)
          #else
            #error "not implemented"
          #end
        )
        .run(handler).eager()
      #if tink_runloop ) #end, 
    #end
  
  ];
  
  public static var clients: Array<ClientType> = ClientType.createAll();
  #end
  
  #if neko
  
  static function targetArgs(port: Int) {
    var args = ['-lib tink_unittest', '-D port=$port', '-main RunTests'];
    if(Env.getDefine('container_only') != null) args.push('-D container_only');
    return args;
  }
    
  static function travixTarget(name, port: Int)
    return ProcessTools.travix(name, targetArgs(port));
    
  static function tcpTarget(name, port: Int)
    return ProcessTools.travix(name, targetArgs(port).concat(['-lib tink_tcp']));
  
  public static var targets: Map<String, Int -> Process> = [
    'neko' => travixTarget.bind('neko'),
    'node' => travixTarget.bind('node'),
    'php' => travixTarget.bind('php'),
    'java' => travixTarget.bind('java'),
    'cs' => travixTarget.bind('cs'),
    'cpp' => travixTarget.bind('cpp'),
    'js' => travixTarget.bind('js'),
    'lua' => travixTarget.bind('lua'),
    'hl' => travixTarget.bind('hl'),
    
    'neko-tcp' => tcpTarget.bind('neko'),
  ];
  
  #end
}
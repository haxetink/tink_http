package;

#if (server=='NekoToolsServer')
typedef Server = server.NekoToolsServer;

#elseif (server=='ModNekoServer')
typedef Server = server.ModNekoServer;

#elseif (server=='PhpServer')
typedef Server = server.PhpServer;

#elseif (server=='NekoServer')
typedef Server = server.NekoServer;

#elseif (server=='JavaServer')
typedef Server = server.JavaServer;

#elseif (server=='NodeServer')
typedef Server = server.NodeServer;

#end
package;

#if (client=='NekoClient')
typedef Client = client.NekoClient;

#elseif (client=='NodeClient')
typedef Client = client.NodeClient;

#elseif (client=='PhpClient')
typedef Client = client.PhpClient;

#elseif (client=='JavaClient')
typedef Client = client.JavaClient;

#end
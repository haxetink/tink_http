package;

#if (client=='NekoClient')
typedef Client = client.NekoClient;

#elseif (client=='PhpClient')
typedef Client = client.PhpClient;

#end
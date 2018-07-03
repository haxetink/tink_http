package;

enum ClientType {
  
  #if sys
  Socket;
  #end
  
  #if (js && !nodejs)
  Js;
  #end
  
  #if nodejs
  Node;
  #end
  
  #if tink_tcp
  Tcp;
  #end
  
  #if ((nodejs || sys) && !php) // TODO: php fails to read from stdout of curl process
  Curl;
  #end
  
  #if flash
  Flash;
  #end
}
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
  
  #if sys
  // Socket;
  #end
  
  #if tink_tcp
  Tcp;
  #end
  
  #if (nodejs || sys)
  Curl;
  #end
  
  #if flash
  Flash;
  #end
}
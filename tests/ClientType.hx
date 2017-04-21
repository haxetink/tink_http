package;

enum ClientType {
  #if (js && !nodejs)
  Js;
  #end
  
  #if nodejs
  Node;
  Curl;
  #end
}
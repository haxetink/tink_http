package tink.http.containers;

import tink.http.Container;

using tink.io.Source;
using tink.CoreApi;

/**
 * Calling run() will export your handler via `exports[name]`
 * as demonstrated in the official documentation:
 * https://firebase.google.com/docs/functions/get-started#add-the-addmessage-function
 * Note that you must do so in the main() function synchronously
 * otherwise the runtime will not be able to pick it up
 */
class FirebaseFunctionsContainer implements Container {
	var name:String;
	var regions:Regions;
	var options:RuntimeOptions;
	
	public function new(name, ?regions, ?options) {
		this.name = name;
		this.regions = regions;
		this.options = options;
	}
	
	public function run(handler:Handler):Future<ContainerResult> {
		return Future #if (tink_core >= "2") .irreversible #else .async #end(function(cb) {	
			Reflect.setField(
				js.Node.exports,
				name,
				{
					var f:FunctionBuilder = FirebaseFunctions;
					if(regions != null) f = f.region(js.Syntax.code('...{0}', regions));
					if(options != null) f = f.runWith(options);
					f.https.onRequest(handler.toNodeHandler({
						// https://firebase.google.com/docs/functions/http-events#read_values_from_the_request
						body: function(msg) {
							var buffer:js.node.Buffer = untyped msg.rawBody;
							return Plain(buffer == null ? Source.EMPTY : (buffer:tink.Chunk));
						}
					}));
				}
			);
			
			// firebase function will kill this node process when the request is done
			js.Node.process.on('exit', cb.bind(Shutdown));
		});
		
	}
}

private abstract Regions(Array<String>) from Array<String> to Array<String>{
	@:from public static inline function fromString(region:String):Regions return [region];
}

private typedef Common = {
	var https:HttpsFunction;
	function region(regions:haxe.extern.Rest<String>):FunctionBuilder;
	function runWith(options:RuntimeOptions):FunctionBuilder;
}

// https://github.com/firebase/firebase-functions/blob/master/src/index.ts
@:jsRequire('firebase-functions')
private extern class FirebaseFunctions {
	static var https:HttpsFunction;
	static function region(regions:haxe.extern.Rest<String>):FunctionBuilder;
	static function runWith(options:RuntimeOptions):FunctionBuilder;
}

// https://github.com/firebase/firebase-functions/blob/master/src/function-builder.ts
private typedef FunctionBuilder = {
	var https:HttpsFunction;
	function region(regions:haxe.extern.Rest<String>):FunctionBuilder;
	function runWith(options:RuntimeOptions):FunctionBuilder;
}

// https://github.com/firebase/firebase-functions/blob/master/src/providers/https.ts
private extern class HttpsFunction {
	function onRequest(handler:js.node.http.IncomingMessage->js.node.http.ServerResponse->Void):HttpsFunction;
}

// https://github.com/firebase/firebase-functions/blob/master/src/function-configuration.ts
private typedef RuntimeOptions = {
	?memory:String,
	?timeoutSeconds:Int,
}
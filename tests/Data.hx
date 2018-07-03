typedef Data = {
	uri: String,
	ip: String,
	query: haxe.DynamicAccess<String>,
	method: String,
	headers: Array<{name:String, value:String}>,
	body: String
}
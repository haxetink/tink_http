typedef Data = {
	uri: String,
	ip: String,
	method: String,
	headers: Array<{name:String, value:String}>,
	body: {
    type: String, //plain/parsed/none
    ?parts: Array<{name: String, value: String}>,
    ?content: String
  }
}
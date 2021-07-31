
exports.failureCallback = function failureCallback(err){
	console.log('Error detected:\n'.red, err)
	const errString = err.toString();
	if(errString.includes('message')) {
		return errString.substring(errString.indexOf('message')+8);
	} else {
		return err;
	}
}



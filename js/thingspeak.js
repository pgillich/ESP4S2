(function(ext) {
	ext.statusCount = 10;
	ext.chanId = 0;
	ext.keyWrite = "";
	ext.keyRead = "";
	
	
    // Cleanup function when the extension is unloaded
    ext._shutdown = function() {};

    // Status reporting code
    // Use this to report missing hardware, plugin or unsupported browser
    ext._getStatus = function() {
    	if (ext.statusCount > 0) {
    		ext.statusCount--;
    		return {status: 2, msg: 'Initialization'};
    	}
    	ext.statusCount = 0;
    	
    	if (ext.chanId == 0 || ext.keyWrite.length != 16) {
    		return {status: 0, msg: "Please set keys!"};
    	} 

        return {status: 2, msg: 'Ready'};
    };

    ext.setKeys = function(chanId, keyWrite, keyRead) {
    	ext.chanId = chanId;
    	ext.keyWrite = keyWrite;
    	ext.keyRead = keyRead;
    };

    function sendRequest(path, parameters, callback) {
    	var uri = "https://api.thingspeak.com/"+path+"?"+$.param(parameters);
    	console.log("GET "+uri);
    	$.ajax({
    		url: uri,
    		crossDomain: true,
    	}).done( function(data, textStatus, jqXHR) {
        	console.log("done: "+data);
    		if (callback != null) {
    			callback(data);
    			return;
    		}
    		return data;
    	}).fail( function(jqXHR, textStatus, errorThrown) {
    		console.log("fail: "+textStatus+": "+errorThrown);
    		if (callback != null) {
    			callback(textStatus);
    		}
    	});
    	
    	return "";
    }
    
    ext.updateField = function(field, value, callback) {
    	var parameters = {api_key: ext.keyWrite};
    	parameters["field"+field] = value;
    	return sendRequest("update", parameters, callback);
    };

    ext.getField = function(field, callback) {
    	var parameters = {};
    	if (ext.keyRead != "") {
    		parameters.api_key = ext.keyRead;
    	}
    	return sendRequest("channels/"+encodeURIComponent(ext.chanId)+"/fields/"+encodeURIComponent(""+field)+"/last.txt", parameters, callback);
    };

    // Block and block menu descriptions
    var descriptor = {
        blocks: [
    		[" ", "Channel ID: %s; write key: %s; read key: %s", "setKeys", 0, "", ""],
    		["w", "Update field %n = %n", "updateField", 1, 0],
    		["R", "Get field %n", "getField", 1],
        ],
        url: 'https://pgillich.github.io/ESP4S2/js',
    };

    // Register the extension
    ScratchExtensions.register('Sample extension', descriptor, ext);
})({});
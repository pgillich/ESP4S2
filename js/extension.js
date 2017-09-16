/*
 https://raw.githubusercontent.com/LLK/scratchx/master/random_wait_extension.js
*/

(function(ext) {
    // Cleanup function when the extension is unloaded
    ext._shutdown = function() {};

    // Status reporting code
    // Use this to report missing hardware, plugin or unsupported browser
    ext._getStatus = function() {
        return {status: 2, msg: 'Ready'};
    };

    // Functions for block with type 'w' will get a callback function as the 
    // final argument. This should be called to indicate that the block can
    // stop waiting.
    ext.wait_random = function(callback) {
        wait = Math.random();
        console.log('Waiting for ' + wait + ' seconds');
        window.setTimeout(function() {
            callback();
        }, wait*1000);
    };

    function sendRequest(parameter) {
    	$.ajax({
    		url: "http://localhost:58266/"+parameter,
    		crossDomain: true,
    	}).done( function(data, textStatus, jqXHR) {
    		console.log(""+textStatus+": "+data);
    		return data;
    	}).fail( function(jqXHR, textStatus, errorThrown) {
    		console.log(""+textStatus+": "+errorThrown);
    	});
    	
    	return "";
    }
    
    ext.initNet = function(net, maskBits) {
    	return sendRequest("initNet/"+net+"/"+maskBits);
    }
    
    // Block and block menu descriptions
    var descriptor = {
        blocks: [
            ['w', 'wait for random time', 'wait_random'],
    		[" ", "Set network %s / %n", "initNet", "192.168.10.0", "24"],
        ]
    };

    // Register the extension
    ScratchExtensions.register('ESP for Scratch 2', descriptor, ext);
})({});
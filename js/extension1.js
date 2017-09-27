/* Based on:
 https://raw.githubusercontent.com/LLK/scratchx/master/random_wait_extension.js
*/

(function(ext) {
	ext.statusMsg = "Initializing";
	ext.statusCount = 10;
	ext.hasBridge = false;
	ext.poller = null;
	ext.subnet = null;
	ext.polls = {};
	ext.pollIval = 500;
	ext.device = "";
	
    // Cleanup function when the extension is unloaded
    ext._shutdown = function() {
    	if (ext.poller !== null) {
    		clearInterval(ext.poller);
    	} 
    	ext.poller = null;
    };

    // Status reporting code
    // Use this to report missing hardware, plugin or unsupported browser
    ext._getStatus = function() {
    	if (ext.statusCount > 0) {
    		ext.statusCount--;
    		return {status: 2, msg: 'Initialization'};
    	} else if (!ext.hasBridge) {
        	console.log("_getStatus 0");
        	ext.statusCount = 0
    		return {status: 0, msg: ext.statusMsg};
    	} else if (ext.subnet === null) {
        	console.log("_getStatus 1");
        	ext.statusCount = 0
    		return {status: 1, msg: 'Network?'};
    	}
    	ext.statusCount = 0
        return {status: 2, msg: 'Ready'};
    };

    function sendRequest(parameter, callback) {
    	if (parameter !== "poll") {
    		console.log("sendRequest "+parameter)
    	}
    	$.ajax({
    		url: "http://localhost:58266/"+parameter,
    		crossDomain: true,
    	}).done( function(data, textStatus, jqXHR) {
    		if (parameter !== "poll") {
    			console.log("done: "+textStatus+": "+data);
    		}
    		if (callback != null) {
    			callback(data);
    			return;
    		}
    		return data;
    	}).fail( function(jqXHR, textStatus, errorThrown) {
    		console.log("fail: "+textStatus+": "+errorThrown);
    		// ext.hasBridge = false;
    		if (callback != null) {
    			callback(textStatus);
    		}
    	});
    	
    	return "";
    }
    
    function polling() {
    	if (ext.hasBridge) {
    		ext.poll();
    	} else {
    		ext.resetAll();
    	}
    }

    function handleResetAll(response) {
    	console.log("handleResetAll:"+response);
    	if (response === "okay") {
    		ext.hasBridge = true;
    	} else {
    		ext.statusMsg = "Bridge: "+response;
    	}
    }

    function handlePoll(response) {
    	// console.log(response);
    	var lines = response.split("\n");
    	var line = "";
    	var l, k = 0;
    	var kv, keys = [];
    	var value = "";
    	var poll = ext.polls;
    	for (l=1; l<lines.length; l++) {
    		line = lines[l];
    		//console.log(line);
    		if (line.length > 0 && line.indexOf(" ") !== -1) {
    			kv = line.split(" ", 2);
    			value = kv[1];
    			keys = kv[0].split("/");
    			poll = ext.polls;
    			for (k=0; k<keys.length-1; k++) {
    				if (poll[keys[k]] === undefined) {
    					poll[keys[k]] = {};
					}
    				
    				poll = poll[keys[k]];
    			}
    			poll[keys[k]] = value;
    		}
    	}
    	//console.log(JSON.stringify(ext.polls));
    }

    ext.resetAll = function() {
    	return sendRequest("reset_all", handleResetAll);
    };

    ext.reset = function() {
    	return sendRequest("reset/"+ext.device, handleResetAll);
    };

    ext.poll = function() {
    	return sendRequest("poll", handlePoll);
    };

    ext.initNet = function(net, maskBits, device) {
    	ext.subnet = net+"/"+maskBits;
    	ext.device = device;
    	return sendRequest("initNet/"+ext.subnet);
    };

    ext.pinMode = function(pin, mode) {
    	return sendRequest("pinMode/E/"+ext.device+"/"+pin+"/"+mode);
    };

    ext.digitalWrite = function(pin, value) {
    	return sendRequest("digitalWrite/E/"+ext.device+"/"+pin+"/"+value);
    };

    ext.analogWrite = function(pin, value) {
    	return sendRequest("analogWrite/E/"+ext.device+"/"+pin+"/"+value);
    };

    ext.analogPairWrite = function(pin1, pin2, value) {
    	return sendRequest("analogPairWrite/E/"+ext.device+"/"+pin1+"/"+pin2+"/"+value);
    };

    ext.tankWrite = function(pin1, pin2, pin3, pin4, valueX, valueY) {
    	return sendRequest("tankWrite/E/"+ext.device+"/"+pin1+"/"+pin2+"/"+pin3+"/"+pin4+"/"+valueX+"/"+valueY);
    };

    ext.servoWrite = function(pin, value) {
    	return sendRequest("servoWrite/E/"+ext.device+"/"+pin+"/"+value);
    };

    ext.print = function(pin, value) {
    	var text = encodeURIComponent(value.replace(/\\n/g, "\\n"))
    	return sendRequest("print/E/"+ext.device+"/"+pin+"/"+text);
    };

    ext.digitalRead = function(pin, callback) {
    	try {
    		var value = ext.polls["digitalRead"][ext.device][pin];
    		console.log("digitalRead="+value);
    		return (value == "true" || value == "1");
    	} finally {}
    	return "";
    };

    ext.analogRead = function(pin, callback) {
    	try {
    		return ext.polls["analogRead"][ext.device][pin];
    	} finally {}
    	return "";
    };

    // Block and block menu descriptions
    var descriptor = {
        blocks: [
    		[" ", "Set network %s / %n On %s", "initNet", "192.168.10.0", "24", "tank"],
    		[" ", "Reset", "reset1"],
    		[" ", "pin %n mode= %m.mode", "pinMode", 4, "Digital Input"],
    		[" ", "pin %n digital= %m.highLow", "digitalWrite", 4, "High"],
    		[" ", "pin %n PWM= %n", "analogWrite", 5, 100],
    		[" ", "pins (%n %n ) PWM motor= %n", "analogPairWrite", 5, 6, 0],
    		[" ", "pins (%n %n %n %n ) PWM tank= (%n %n )", "tankWrite", 5, 6, 7, 3, 0, 0],
    		[" ", "pin %n servo degrees= %n", "servoWrite", 5, 180],
    		[" ", "pin %n print %s", "print", 0, "Hello"],
    		["b", "pin %n digital?", "digitalRead", 0],
    		["r", "pin %n analog?", "analogRead", 15],
        ],
        menus: {
    		mode: ["Digital Input", "Digital Output","Analog Input","Analog Output(PWM)","Servo"],
    		highLow: ["High", "Low"],
    		execWait: ["E", "W"],
        },
        url: 'https://pgillich.github.io/ESP4S2/'
    };

    ext.poller = setInterval(polling, ext.pollIval);

    // Register the extension
    ScratchExtensions.register('ESP for Scratch 2', descriptor, ext);
})({});
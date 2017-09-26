/*
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
    		ext.hasBridge = false;
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

    ext.poll = function() {
    	return sendRequest("poll", handlePoll);
    };

    ext.initNet = function(net, maskBits) {
    	ext.subnet = net+"/"+maskBits;
    	return sendRequest("initNet/"+ext.subnet);
    };

    ext.pinMode = function(exec_wait, device, pin, mode) {
    	return sendRequest("pinMode/"+exec_wait+"/"+device+"/"+pin+"/"+mode);
    };

    ext.digitalWrite = function(exec_wait, device, pin, value) {
    	return sendRequest("digitalWrite/"+exec_wait+"/"+device+"/"+pin+"/"+value);
    };

    ext.analogWrite = function(exec_wait, device, pin, value) {
    	return sendRequest("analogWrite/"+exec_wait+"/"+device+"/"+pin+"/"+value);
    };

    ext.analogPairWrite = function(exec_wait, device, pin1, pin2, value) {
    	return sendRequest("analogPairWrite/"+exec_wait+"/"+device+"/"+pin1+"/"+pin2+"/"+value);
    };

    ext.tankWrite = function(exec_wait, device, pin1, pin2, pin3, pin4, valueX, valueY) {
    	return sendRequest("tankWrite/"+exec_wait+"/"+device+"/"+pin1+"/"+pin2+"/"+pin3+"/"+pin4+"/"+valueX+"/"+valueY);
    };

    ext.servoWrite = function(exec_wait,  device, pin, value) {
    	return sendRequest("servoWrite/"+exec_wait+"/"+device+"/"+pin+"/"+value);
    };

    ext.print = function(exec_wait, device, pin, value) {
    	var text = encodeURIComponent(value.replace(/\\n/g, "\\n"))
    	return sendRequest("print/"+exec_wait+"/"+device+"/"+pin+"/"+text);
    };

    ext.digitalRead = function(device, pin, callback) {
    	try {
    		var value = ext.polls["digitalRead"][device][pin];
    		console.log("digitalRead="+value);
    		return (value == "true" || value == "1");
    	} finally {}
    	return "";
    };

    ext.analogRead = function(device, pin, callback) {
    	try {
    		return ext.polls["analogRead"][device][pin];
    	} finally {}
    	return "";
    };

    // Block and block menu descriptions
    var descriptor = {
        blocks: [
    		[" ", "Set network %s / %n", "initNet", "192.168.10.0", "24"],
    		[" ", "%m.execWait On %s pin %n mode= %m.mode", "pinMode", "E", "met", 4, "Digital Input"],
    		[" ", "%m.execWait On %s pin %n digital= %m.highLow", "digitalWrite", "E", "tank-tower", 4, "High"],
    		[" ", "%m.execWait On %s pin %n PWM= %n", "analogWrite", "E", "tank-tower", 5, 100],
    		[" ", "%m.execWait On %s pins (%n %n ) PWM motor= %n", "analogPairWrite", "E", "tank-tower", 5, 6, 0],
    		[" ", "%m.execWait On %s pins (%n %n %n %n ) PWM tank= (%n %n )", "tankWrite", "E", "tank-chassis", 5, 6, 7, 3, 0, 0],
    		[" ", "%m.execWait On %s pin %n servo degrees= %n", "servoWrite", "E", "tank-tower", 5, 180],
    		[" ", "%m.execWait On %s pin %n print %s", "print", "E", "oled", 0, "Hello"],
    		["b", "On %s pin %n digital?", "digitalRead", "met", 0],
    		["r", "On %s pin %n analog?", "analogRead", "met", 0],
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
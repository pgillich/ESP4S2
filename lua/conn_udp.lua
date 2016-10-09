function initUdp(dataReceiver)
	if config.listen.port>0 then
		print("UDP: Init listener :"..config.listen.port)
		connListener=net.createServer(net.UDP) 
		connListener:on("receive", dataReceiver) 
		connListener:listen(config.listen.port)     
	end
end

function closeUdp()
	print("UDP: Close")
	connListener=nil
end

function sendUdp(body)
	connListener(body)
end

sendBody=sendUdp
initConnection=initUdp
closeConnection=closeUdp

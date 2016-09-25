function initUdp(dataReceiver)
	if config.listen.port>0 then
		print("UDP: Init listener :"..config.listen.port)
		connListener=net.createServer(net.UDP) 
		connListener:on("receive", dataReceiver) 
        connListener:listen(config.listen.port)     
	end
	if config.target.port>0 and string.len(config.target.addr)>0 then
		print("UDP: Init sender "..config.target.addr..":"..config.target.port)
		connSender=net.createConnection(net.UDP,0)
		connSender:on("sent", function(sck) print("UDP: Sent") end )
		connSender:connect(config.target.port, config.target.addr)
	end
end

function closeUdp()
	print("UDP: Close")
	connListener=nil
	connSender=nil
end

function sendUdp(body)
	connListener(body)
--	if connSender~=nil then
--		print("UDP: Sending "..body)
--		connSender:send(body)
--	end
end

sendBody=sendUdp
initConnection=initUdp
closeConnection=closeUdp

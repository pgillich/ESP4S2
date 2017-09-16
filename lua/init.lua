-- This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
-- Copyright (C) 2016 pgillich, under GPLv3 license.

-- RELOAD PROTECTION BEGIN
if init_loaded~=nil then
print("init.lua already loaded!")
else
init_loaded=true
-- RELOAD PROTECTION END

print("M: "..tostring(node.heap()))

-- WiFi config

dofile("secure.lua")

MAC_ID=wifi.sta.getmac()
while string.len(MAC_ID)==0 do
	tmr.now()
	MAC_ID=wifi.sta.getmac()
end
MAC_ID=string.gsub(MAC_ID,":","")

-- MAC address dependent config
dofile("config.lua")

if type(MAC_config[WIFI_CFG_NAME])~=nil and type(MAC_config[WIFI_CFG_NAME][MAC_ID])~=nil then
	config=MAC_config[WIFI_CFG_NAME][MAC_ID]
else
	config={name="unknown",
		wifiMode=wifi.NULLMODE,
		ip="",
		static_ip=false,
		net_type=0,
		listen={port=0},
		devices={},
		tank={},
	}
end

-- Wifi init

WIFI_TMR=0
WIFI_TMR_INTERVAL=1000

SERVER_PORT=config.listen.port

connListener=nil

device_hcsr=nil
function readDevices()
	for dev,params in pairs(config.devices) do
		if dev=="hcsr" then
			if device_hcsr~=nil and PINS_state[device_hcsr.echo]["m"]==MODE_ANALOG then
				PINS_state[device_hcsr.echo]["v"]=device_hcsr.value/58
			end
		end
	end
end

function setupDevices()
	for dev,params in pairs(config.devices) do
		if dev=="hcsr" then
			dofile("hcsr.lua") 
			device_hcsr=hcsr.init(params["pin_trig"], params["pin_echo"], params["absorber"], params["tmr_id"], params["tmr_ms"]) 
			PINS_state[device_hcsr.trig]["m"]=MODE_UNAVAILABLE
			PINS_state[device_hcsr.echo]["m"]=MODE_ANALOG
			device_hcsr.start()
		end
	end
end

function sendData(sck,data)
--	if string.len(data)==0 then
--		data=" "
--	end
	print("< "..data)
	data=data.."\n"
	sck:send(data)
end

recv_cmd=""
function receiveData(sck,data)
	recv_cmd=recv_cmd..data
	local a,b=string.find(recv_cmd,"\n",1,true)
	local resp=""
	while a do
		local cmd=string.sub(recv_cmd,1,a-1)
		local respA=exeCmd(cmd)
		if string.len(resp)>0 then
			resp=resp.."\n"
		end
		resp=resp..respA
		recv_cmd=string.sub(recv_cmd,a+1,string.len(recv_cmd))
		a,b=string.find(recv_cmd,"\n",1,true)
	end
	sendData(sck,resp)
end

function setupConnection()
	if config.net_type==net.UDP then
		dofile("conn_udp.lua")
	elseif config.net_type==net.TCP then
		dofile("conn_tcp.lua")
	end
	
	initConnection(receiveData)
end

function setupFinished()
	print("Setup finished, M: "..tostring(node.heap()))
end

function initServices()
	dofile("pin.lua")
	dofile("command_const.lua")
	dofile("command.lua")
	print("M: "..tostring(node.heap()))
	setupConnection()
	setupDevices()
	setupFinished()
end

print("Init WiFi")
wifi.setmode(config.wifiMode)
if config.wifiMode~=wifi.NULLMODE then
	if config.wifiMode==wifi.STATION then
		if config.static_ip then
			wifi.sta.setip(config)
		end
		print("Connecting WiFi... MAC="..MAC_ID.." SSID="..WIFI_CFG[WIFI_CFG_NAME].ssid)
		wifi.sta.config(WIFI_CFG[WIFI_CFG_NAME].ssid,WIFI_CFG[WIFI_CFG_NAME].pwd,1)
		wifi.sta.connect()

		function wait_wifi()
			local ip=wifi.sta.getip()
			print(ip or "WiFi:"..tostring(wifi.sta.status()))
			if wifi.sta.status()==2 then
				ip=config.ip
				print("WRONG PW, using static IP: "..ip)
			elseif wifi.sta.status()==3 or wifi.sta.status()==4 then
				ip=config.ip
				print("NO/BAD AP, using static IP: "..ip)
			end
			if (ip) then
				tmr.stop(WIFI_TMR)
				print("Listening on "..ip..":"..SERVER_PORT)
				initServices()
			end
		end

		tmr.alarm(WIFI_TMR,WIFI_TMR_INTERVAL,1,wait_wifi)
	elseif config.wifiMode==wifi.SOFTAP then
		print("AP WiFi... MAC="..MAC_ID.." SSID="..WIFI_CFG[WIFI_CFG_NAME].ssid)
		wifi.ap.setip(config)
		wifi.ap.config(WIFI_CFG[WIFI_CFG_NAME])
		local ip=config.ip
		print("Listening on "..ip..":"..SERVER_PORT)
		initServices()
	end
end

-- RELOAD PROTECTION BEGIN
end
-- RELOAD PROTECTION END

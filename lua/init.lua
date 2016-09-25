-- This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
-- Copyright (C) 2016 pgillich
--
--     ESP4S2 is free software: you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation, either version 3 of the License, or
--     (at your option) any later version.
--
--     ESP4S2 is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
--
--     You should have received a copy of the GNU General Public License
--     along with ESP4S2. If not, see <http://www.gnu.org/licenses/>.

dofile("secure.lua")

MAC_ID=wifi.sta.getmac()
while string.len(MAC_ID)==0 do
	tmr.now()
	MAC_ID=wifi.sta.getmac()
end
MAC_ID=string.gsub(MAC_ID,":","")

connListener=nil
connSender=nil

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
		target={ip="",port=0},
		devices={}
	}
end

-- Wifi init
WIFI_TMR=0
WIFI_TMR_INTERVAL=1000

SERVER_PORT=config.listen.port

MODE_UNAVAILABLE=-1
MODE_INPUT=0
MODE_OUTPUT=1
MODE_ANALOG=2
MODE_PWM=3
MODE_SERVO=4

PIN_MODES={
	[MODE_UNAVAILABLE]="UNAVAILABLE",
	[MODE_INPUT]="INPUT",
	[MODE_OUTPUT]="OUTPUT",
	[MODE_ANALOG]="ANALOG",
	[MODE_PWM]="PWM",
	[MODE_SERVO]="SERVO"
}

PINS_state={
	[0]={m=-1,v=-1},
	[1]={m=-1,v=-1},
	[2]={m=-1,v=-1},
	[3]={m=-1,v=-1},
	[4]={m=-1,v=-1},
	[5]={m=-1,v=-1},
	[6]={m=-1,v=-1},
	[7]={m=-1,v=-1},
	[8]={m=-1,v=-1},
	[11]={m=-1,v=-1},
	[12]={m=-1,v=-1},
}

local function csplit(str,sep)
	local ret={}
	local n=1
	for w in str:gmatch("([^"..sep.."]*)") do
		ret[n]=ret[n] or w
		if w=="" then n=n+1 end
	end
	return ret
end

function pinMode(pin,mode)
	local resp=""
	if type(PINS_state[pin])~=nil and type(PIN_MODES[mode])~=nil then
		print("  pinMode("..tostring(pin)..","..tostring(mode)..")")
		change2mode(pin,mode,PINS_state[pin]["m"])
		PINS_state[pin]["m"]=mode
	end
	return resp
end

function digitalWrite(pin,val)
	local resp=""
	if type(PINS_state[pin])~=nil and PINS_state[pin]["m"]==MODE_OUTPUT then
		if val==0 or val==1 then
			print("  digitalWrite("..tostring(pin)..","..tostring(val)..")")
			change2value(pin, PINS_state[pin]["m"], val, PINS_state[pin]["v"])
			PINS_state[pin]["v"]=val
		end
	else
		print("ERR: invalid digitalWrite("..tostring(pin)..","..tostring(val)..")")
	end
	return resp
end

function analogWrite(pin,val)
	local resp=""
	if type(PINS_state[pin])~=nil and PINS_state[pin]["m"]==MODE_PWM then
		if val>=0 and val<=100 then
			print("  analogWrite("..tostring(pin)..","..tostring(val)..")")
			change2value(pin, PINS_state[pin]["m"], val, PINS_state[pin]["v"])
			PINS_state[pin]["v"]=val
		end
	else
		print("ERR: invalid analogWrite("..tostring(pin)..","..tostring(val)..")")
	end
	return resp
end

function resetAll()
	local resp=""
	
	return resp
end

function getName()
	return "name "..config.name
end

function getValue(pin)
	if type(PINS_state[pin])~=nil then
		if pin==0 and PINS_state[pin]["m"]==MODE_ANALOG then
			return adcRead(pin)
		elseif PINS_state[pin]["m"]==MODE_ANALOG then
			readDevices()
			return PINS_state[pin]["v"]
		elseif PINS_state[pin]["m"]==MODE_INPUT then
			return gpioRead(pin)
		end
	end
	return -1
end

function poll()
	local data=""
	readDevices()
	for pin,mv in pairs(PINS_state) do
		local m=mv["m"]
		local v=mv["v"]
		if type(m)~=nil and (m==MODE_INPUT or m==MODE_ANALOG) then
			if string.len(data)>0 then
				data=data..";"
			end
			data=data..tostring(pin).." "..tostring(v)
		end
	end
	return data
end

function exeCmd(st)
	local resp=""
	print("> "..st)
	local command=csplit(st," ")
	if #command==1 then
		local cmd=command[1]
		if cmd=="reset_all" then
			resp=resetAll()
		elseif cmd=="getName" then
			resp=getName()
		elseif cmd=="poll" then
			resp=poll()
		end
	elseif #command==2 then
		local cmd=command[1]
		local pin=tonumber(command[2])
		if cmd=="digitalRead" then
			resp=tostring(pin).." "..tostring(getValue(pin))
		elseif cmd=="analogRead" then
			resp=tostring(pin).." "..tostring(getValue(pin))
		end
	elseif #command==3 then
		local cmd=command[1]
		local pin=tonumber(command[2])
		local val=tonumber(command[3])
		if cmd=="pinMode" then
			resp=pinMode(pin,val)
		elseif cmd=="digitalWrite" then
			resp=digitalWrite(pin,val)
		elseif cmd=="analogWrite" then
			resp=analogWrite(pin,val)
		end
	elseif #command==4 then
		local cmd=command[1]
		local pin1=tonumber(command[2])
		local pin2=tonumber(command[3])
		local val=tonumber(command[4])
		if cmd=="analogPairWrite" then
			if val>0 then
				resp=analogWrite(pin1,val)
				resp=analogWrite(pin2,0)
			elseif val<0 then
				resp=analogWrite(pin1,0)
				resp=analogWrite(pin2,0-val)
			else
				resp=analogWrite(pin1,0)
				resp=analogWrite(pin2,0)
			end
		end
	else
		print("ERR: unknown command")
	end
	return resp
end

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

function sendData(sck,data)
	if string.len(data)==0 then
		data=" "
	end
	print("Send back data: "..data)
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
			resp=resp..";"
		end
		resp=resp..respA
		recv_cmd=string.sub(recv_cmd,a+1,string.len(recv_cmd))
		a,b=string.find(recv_cmd,"\n",1,true)
	end
	sendData(sck,resp)
end

function gpioMode(pin,val)
	print("   gpio.mode("..tostring(pin)..","..tostring(val)..")")
	gpio.mode(pin,val)
end

function gpioWrite(pin,val)
	print("   gpio.write("..tostring(pin)..","..tostring(val)..")")
	gpio.write(pin,val)
end

function pwmStop(pin)
	print("   pwm.stop("..tostring(pin)..")")
	pwm.stop(pin)
end

function pwmStart(pin)
	print("   pwm.setup("..tostring(pin)..",1000,0)")
	pwm.setup(pin,1000,0)
	print("   pwm.start("..tostring(pin)..")")
	pwm.start(pin)
end

function pwmSetduty(pin,val)
	print("   pwm.setduty("..tostring(pin)..","..tostring(val)..")")
	pwm.setduty(pin, val*1023/100) 	
end

function gpioRead(pin)
	local val=gpio.read(pin)
	print("   gpio.read("..tostring(pin)..")="..tostring(val))
	PINS_state[pin]["v"]=val
	return val
end

function adcRead(pin)
	if pin==0 then
		local val=adc.read(pin)
		print("   adc.read("..tostring(pin)..")="..tostring(val))
		PINS_state[pin]["v"]=val
		return val
	else
		print("ERR: pin not enabled for ADC:"..tostring(pin))
	end
	return -1
end

function change2mode(pin,mode,oldMode)
	if mode~=oldMode then
		if oldMode==MODE_PWM then
			pwmStop(pin)
		end
	
		if mode==MODE_INPUT then
			gpioMode(pin, gpio.INPUT)
		elseif mode==MODE_OUTPUT then
			gpioMode(pin, gpio.OUTPUT)
		elseif mode==MODE_PWM then
			pwmStart(pin)
		else
			print("ERR: unknown mode, "..tostring(mode))
		end
	end
end

function change2value(pin,mode,val,oldVal)
	if mode==MODE_OUTPUT then
		gpioWrite(pin,val)
	elseif mode==MODE_PWM then
		pwmSetduty(pin,val)
	else
		print("ERR: unknown mode, "..tostring(mode))
	end
end

function setupConnection()
	if config.net_type==net.UDP then
		dofile("conn_udp.lua")
	elseif config.net_type==net.TCP then
		dofile("conn_tcp.lua")
	end
	
	initConnection(receiveData)
end

function setupDevices()
	for dev,params in pairs(config.devices) do
		if dev=="hcsr" then
			dofile("hcsr.lua") 
			device_hcsr=hcsr.init(params["pin_trig"], params["pin_echo"], params["absorber"], params["tmr_id"], params["tmr_ms"]) 
			PINS_state[device_hcsr.trig]["m"]=MODE_OUTPUT
			PINS_state[device_hcsr.echo]["m"]=MODE_ANALOG
			device_hcsr.start()
		end
	end
end

function setupFinished()
	print("Setup finished, free: "..tostring(node.heap()))
end

function initServices()
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

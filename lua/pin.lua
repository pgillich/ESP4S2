-- This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
-- Copyright (C) 2016 pgillich, under GPLv3 license

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

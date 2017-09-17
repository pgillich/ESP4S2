-- This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
-- Copyright (C) 2016, 2017 pgillich, under GPLv3 license.

function adcRead(p)
	if p==0 then
		local v=adc.read(p)
		dpr("adc.read",p,v)
		return v
	end
	print("ERR: not for ADC:"..tostring(p))
	return -1
end
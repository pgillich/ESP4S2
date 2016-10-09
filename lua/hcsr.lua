-- HC-SR04 example for NodeMCU
-- Original source from https://github.com/sza2/node_hcsr04
--   main change: replacing tmr.delay to tmr.alert
-- Optimized for WeMos D1 mini, see more:
--   http://www.wemos.cc/Products/d1_mini.html
-- Sensor pins:
--   ECHO: D8 (GPIO15) pulled down by 10k (R2) on WeMos D1 mini
--     R1 between ECHO and D8 as voltage divider: 4k7, see more:
--     http://www.modmypi.com/blog/hc-sr04-ultrasonic-range-sensor-on-the-raspberry-pi
--   TRIG: D0 (GPIO16)
--     Can only be used as gpio read/write. No support for open-drain/interrupt/pwm/i2c/ow.
--   VCC: 5V
--   GND: G
-- Trig time: min. 10 us
-- Max echo time: 38 ms
-- Usage:
--   dofile("hcsr.lua") device=hcsr.init() device.start()

HCSR_TRIG_DEFAULT = 0
HCSR_ECHO_DEFAULT = 8
HCSR_ABSORBER_DEFAULT = 2
HCSR_TMR_ID_DEFAULT = 6
HCSR_TMR_MS_DEFAULT = 500
HCSR_TRIG_US = 10

hcsr = {};

function hcsr.init(pin_trig, pin_echo, absorber, tmr_id, tmr_ms)
	local self = {}
	self.tmr_id = tmr_id or HCSR_TMR_ID_DEFAULT
	tmr.stop(self.tmr_id)
	
	self.time_start = 0
	self.time_end = 0
	self.trig = pin_trig or HCSR_TRIG_DEFAULT
	self.echo = pin_echo or HCSR_ECHO_DEFAULT
	gpio.mode(self.trig, gpio.OUTPUT)
	gpio.mode(self.echo, gpio.INT)
	self.absorber = absorber or HCSR_ABSORBER_DEFAULT
	self.tmr_ms = tmr_ms or HCSR_TMR_MS_DEFAULT
	self.last = 0
	self.value = 0
	self.dus = 0

	print("HCSR: trig="..tostring(self.trig)..", echo="..tostring(self.echo)..", absorber="..tostring(self.absorber)..", tmr_id="..tostring(self.tmr_id)..", tmr_ms="..tostring(self.tmr_ms))

	function self.sleep(tus)
		local start = tmr.now()
		self.dus = 0 
		while(self.dus < tus) do
			self.dus = tmr.now() - start
		end
	end

	function self.echo_cb(level)
		--print("  self.echo_cb "..level)
		if level == 1 then
			self.time_start = tmr.now()
			gpio.trig(self.echo, "down")
		else
			self.time_end = tmr.now()
			gpio.trig(self.echo, "none")
		end
	end
	
	function self.sendTrig()
		--print("  self.sendTrig")
		self.time_start = 0
		self.time_end = 0
		self.last = 0
		gpio.trig(self.echo, "up", self.echo_cb)
		gpio.write(self.trig, gpio.HIGH)
		self.sleep(HCSR_TRIG_US)
		gpio.write(self.trig, gpio.LOW)
	end

	function self.updateValue()
		local delta = -1
		if self.time_end > 0  then
			delta = self.time_end - self.time_start
			if delta < 0 then delta = delta + 2147483647 end
			self.last = delta
			self.value = self.value + (self.last-self.value)/self.absorber
		else
			--self.last = -1
			--self.value = -1
		end
		 
		--print("cm="..tostring(self.value/58).." start="..self.time_start.." end="..self.time_end)
		if self.value > 0 then
			--print(string.rep(" ", self.value/58).."#")
		else
			--print("-")
		end
	end

	function self.measureWorker()
		--print()
		self.updateValue()
		self.sendTrig()

		--print("  "..node.heap())
		tmr.start(self.tmr_id)
	end
	
	function self.measure()
		local status, err = pcall(self.measureWorker)
		if not status then
			print("HCSR: ERR: "..tostring(err))
		end
	end

	function self.stop()
		tmr.stop(self.tmr_id)
	end

	function self.start()
		self.stop()
		self.measure()
	end
		
	tmr.register(self.tmr_id, self.tmr_ms, tmr.ALARM_SEMI, self.measure)

	return self
end

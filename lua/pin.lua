function gM(p,v)
dp2(3,"gpio.mode",p,v)
gpio.mode(p,v)
end

function gR(p)
local v=gpio.read(p)
dpr(3,"gpio.read",p,v)
return v
end

function gW(p,v)
dp2(3,"gpio.write",p,v)
gpio.write(p,v)
end

function pStop(p)
dp(3,"pwm.stop",p)
pwm.stop(p)
dp(3,"pwm.close",p)
pwm.close(p)
end

function pStart(p)
dp3(3,"pwm.setup",p,1000,0)
pwm.setup(p,1000,0)
dp(3,"pwm.start",p)
pwm.start(p)
end

function pDuty(p,v)
dp2(3,"pwm.setduty",p,v)
pwm.setduty(p,v*1023/100)  
end

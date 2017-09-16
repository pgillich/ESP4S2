HCSR_TUS=10
HCSR_DM=23200

hcsr={}
function hcsr.init(pt,pe,a,tid,tms,V)
local s={}
s.tid=tid
s.tms=tms
tmr.stop(s.tid)
s.ts=0
s.te=0
s.t=pt
s.e=pe
gpio.mode(s.t,gpio.OUTPUT)
gpio.mode(s.e,gpio.INT)
s.a=a
s.last=0
V[pt]=0
V[pe]=0

function s.sleep(tus)
tmr.delay(tus)
end

function s.e_cb(l,t)
if l==1 then
	s.ts=t
	gpio.trig(s.e,"down")
else
	s.te=t
	gpio.trig(s.e,"none")
end
-- P("  s.e_cb "..l)
end

function s.sT()
s.ts=0
s.te=0
gpio.trig(s.e,"up",s.e_cb)
gpio.write(s.t,1)
s.sleep(HCSR_TUS)
gpio.write(s.t,0)
end

function s.uV()
local d=-1
if s.te>0 then
d=s.te-s.ts
if d<0 then d=d+2147483647 end
if d<HCSR_DM then
	s.last=d
	V[pt]=V[pt]+(s.last-V[pt])/s.a
	V[pe]=V[pt]/58
else d=0 end
end
--P("d="..d.." cm="..S(V[pe]).." start="..s.ts.." end="..s.te)
if d>0 then
	dl(0)
	--P(string.rep(" ",V[pe]/10)..S(V[pe]))
else
	dl(1)
	--P("-")
end
end

function s.measW()
gpio.trig(s.e,"none")
s.uV()
s.sT()
tmr.start(s.tid)
end

function s.meas()
local st,err=pcall(s.measW)
if not st then
	P("HCSR ERR: "..S(err))
end
end

function s.stop()
tmr.stop(s.tid)
end

function s.start()
s.stop()
s.meas()
end
	
tmr.register(s.tid,s.tms,tmr.ALARM_SEMI,s.meas)

return s
end

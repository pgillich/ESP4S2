HCSR_TUS=10
hcsr={}

function hcsr.init(pt,pe,a,tid,tms,V)
local s={}
s.tid=tid
P("tmr.stop(s.tid)...")
tmr.stop(s.tid)
P("tmr.stop(s.tid)")
s.ts=0
s.te=0
s.t=pt
s.e=pe
s.a=a
s.tms=tms
s.lt=0
s.dus=0
P("HCSR: t="..S(s.t).." e="..S(s.e).." a="..S(s.a).." tid="..S(s.tid).." tms="..S(s.tms))
V[pt]=0
V[pe]=0
P("HCSR: gpio.mode(s.t,gpio.OUTPUT)...")
gpio.mode(s.t,gpio.OUTPUT)
P("HCSR: gpio.mode(s.e,gpio.INT)...")
gpio.mode(s.e,gpio.INT)
P("HCSR: gpio.mode(s.e,gpio.INT)")

function s.sleep(tus)
	local st=tmr.now()
	s.dus=0 
	while(s.dus<tus) do
		s.dus=tmr.now()-st
	end
end

function s.e_cb(lv)
	dp(3,"e_cb",lv)
	if lv==1 then
		s.ts=tmr.now()
		gpio.trig(s.e,"down")
	else
		s.te=tmr.now()
		gpio.trig(s.e,"none")
	end
end

function s.sT()
	P("   s.sT")
	s.ts=0
	s.te=0
	s.lt=0
	P("gpio.trig(s.e,up,s.e_cb)...")
	gpio.trig(s.e,"up",s.e_cb)
	P("gpio.trig(s.e,up,s.e_cb)")
	gpio.write(s.t,1)
	s.sleep(HCSR_TUS)
	P("dus:"..S(s.dus))
	gpio.write(s.t,0)
end

function s.uV()
	local dt=-1
	if s.te>0 then
		dt=s.te-s.ts
		if dt<0 then dt=dt+2147483647 end
		s.lt=dt
		V[pt]=V[pt]+(s.lt-V[pt])/s.a
		V[pe]=V[pt]/58
	else
		s.lt=0
		V[pt]=0
		V[pe]=0
	end
	P("   cm="..S(V[pe]).." ts="..S(s.ts).." te="..S(s.te))
	if V[pt]>0 then P(string.rep(" ",V[pe]).."#") else P("-") end
end

function s.measureWorker()
	P("measureWorker")
	s.uV()
	s.sT()
	P("M:"..S(node.heap()))
	tmr.start(s.tid)
	P("tmr.start(s.tid)")
end

function s.meas()
	local st,e=pcall(s.measureWorker)
	if not st then
		P("E: HCSR "..S(e))
	end
end

function s.stop()
	tmr.stop(s.tid)
end

function s.start()
	P("s.stop()...")
	s.stop()
	P("s.stop()")
	s.meas()
end
	
tmr.register(s.tid, s.tms, tmr.ALARM_SEMI, s.meas)

return s
end

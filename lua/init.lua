function P(...) print(...) end
function S(t) return tostring(t) end
function SR(...) return string.rep(...) end
function N(s) return tonumber(s) end
function dp(l,c,p) P(string.rep(" ",l)..c.."("..S(p)..")") end
function dp2(l,c,p,p2) P(SR(" ",l)..c.."("..S(p)..","..S(p2)..")") end
function dpr(l,c,p,v) P(SR(" ",l)..c.."("..S(p)..")="..S(v)) end
function dp3(l,c,p,p2,p3) P(SR(" ",l)..c.."("..S(p)..","..S(p2)..","..S(p3)..")") end
function dl(v) if DL>-1 then gpio.write(DL,v) end end
--function dof(fn) local st=pcall(dofile,fn..".lc") if not st then dofile(fn..".lua") end end
function dof(fn) dofile(fn..".lua") end
WS=wifi.sta
Wtmr=0
WtmrIv=1000
connL=nil
--dHcsr=nil

if iLD~=nil then
P("E:init ALR.LD")
return
end
iLD=true
P("M:"..S(node.heap()))

WD={}
function WD.R()
dof("secure")
MAC=WS.getmac()
while string.len(MAC)==0 do
tmr.now()
MAC=WS.getmac()
end
MAC=string.gsub(MAC,":","")
dof("config")
if DL>-1 then gpio.mode(DL,1) dl(0) end
if type(MC[WCN])~=nil and type(MC[WCN][MAC])~=nil then
cfg=MC[WCN][MAC]
else
P(MAC)
cfg={name="unknown",
	wM=wifi.NULLMODE,
	ip="",
	ipS=false,
	nT=0,
	l={p=0},
	d={},
	t={},
}
end
end
WD.R()
WD.R=nil
for n in pairs(MC) do
if n==WCN then
for m in pairs(MC[n]) do
if MC[n][m].name~=cfg.name then MC[n][m]={name=MC[n][m].name} end
end
else
MC[n]=nil
end
end
collectgarbage()
Sp=cfg.l.p
dl(1)

dH=nil
function sDev()
for d,p in pairs(cfg.d) do
if d=="hcsr" then
	P("HCSR:set")
	dof("hcsr") 
	dH=hcsr.init(p.p[1],p.p[2],p["a"],p["tid"],p["tms"],Dv)
	dH.start()
elseif d=="adc" then
	P("ADC:set")
	Dv[p.p]=0
elseif d=="hdt" then
	P("DHT:set")
	Dv[p.p[1]]=0
	Dv[p.p[2]]=0
elseif d=="bmp085" then
	P("BMP:set")
	i2c.setup(0,p.p[1],p.p[2],i2c.SLOW)
	bmp085.setup()
	Dv[p.p[1]]=0
	Dv[p.p[2]]=0
elseif d=="oled" then
	P("OLED:set")
	dof("oled")
	init_oled(p.p[1],p.p[2],p.sla)
	oledText(0," (\\_/)%0a(='.'=)%0a(\")_(\")")
elseif d=="tmr" then
	P("TMR:set")
	tmr.register(p.tid,p.tms,tmr.ALARM_SEMI,rDevs)
	tmr.start(p.tid)
end
end
end

function rDevs()
for p,v in pairs(Dv) do
	if type(v)=="string" or v>=0 then rDev(p) end
end
tmr.start(cfg.d.tmr.tid)
end

function rDev(p)
if Dv[p] ~= nil and (type(Dv[p])=="string" or Dv[p]>=0) then 
if cfg.d["adc"]~=nil and p==cfg.d.adc.p then Dv[p]=adc.read(0)
elseif cfg.d["hdt"]~=nil and p==cfg.d.hdt.p[1] then
	local st,t,h,td,hd=dht.read(p)
	if st==dht.OK then Dv[p]=t.."."..td Dv[cfg.d.hdt.p[2]]=h.."."..hd end
elseif cfg.d["bmp085"]~=nil and p==cfg.d.bmp085.p[1] then
	local t=bmp085.temperature()
	Dv[p]=S(t/10).."."..S(t%10)
	local pr=bmp085.pressure(cfg.d.bmp085.o)
	Dv[cfg.d.bmp085.p[2]]=S(pr/100).."."..S(pr%100)
end
--dpr(3,"rDev",p,Dv[p])
return Dv[p]
end
return ""
end

function sDt(sck,d,port,ip)
if d~="" then P("<"..ip.." "..d) end
if cfg.l["s"]~=nil then port=cfg.l.s end
sck:send(port,ip,d.."\n")
end

rCmd=""
function rDt(sck,d,port,ip)
rCmd=rCmd..d
local a,b=string.find(rCmd,"\n",1,true)
local r=""
while a do
	local cmd=string.sub(rCmd,1,a-1)
	local st,rA=pcall(exeCmd,cmd)
	if string.len(r)>0 then
		r=r.."\n"
	end
	r=r..S(rA)
	rCmd=string.sub(rCmd,a+1,string.len(rCmd))
	a,b=string.find(rCmd,"\n",1,true)
end
sDt(sck,r,port,ip)
end

function sConn()
if cfg.nT==net.UDP then
	dof("conn_udp")
elseif cfg.nT==net.TCP then
	dof("conn_tcp")
end
WD.iC(rDt)
end

function iSrv()
	P("I:S")
	WD.I=nil
	collectgarbage()
	dof("pin")
	dof("command_const")
	dof("command")
	collectgarbage()
	P("M:"..S(node.heap()))
	sConn()
	sDev()
	P("I:End, M:"..S(node.heap()))
end

function WD.I()
dl(0)
wifi.setphymode(WPM)
wifi.setmode(cfg.wM)
if cfg.wM~=wifi.NULLMODE then
if cfg.wM==wifi.STATION then
	if cfg.ipS then WS.setip(cfg) end
	P("W:"..MAC.." "..WC[WCN].ssid)
	WS.config(WC[WCN])
	--WS.config(WC[WCN].ssid,WC[WCN].pwd,1)
	WS.connect()
	function wait_wifi()
		dl(0)
		local ip=WS.getip()
		P(ip or "W:"..S(WS.status()))
		if WS.status()==2 then
			ip=cfg.ip
			WS.setip(cfg)
			P("E:PW, U S IP:"..ip)
		elseif WS.status()==3 or WS.status()==4 then
			ip=cfg.ip
			WS.setip(cfg)
			P("E:AP, U S IP:"..ip)
		end
		if (ip) then
			tmr.stop(Wtmr)
			P("L:"..ip..":"..Sp)
			iSrv()
		else
			dl(1)
		end
	end
	tmr.alarm(Wtmr,WtmrIv,1,wait_wifi)
elseif cfg.wM==wifi.SOFTAP then
	dl(1)
	P("W:AP "..MAC.." "..WC[WCN].ssid)
	wifi.ap.setip(cfg)
	wifi.ap.config(WC[WCN])
	local ip=cfg.ip
	P("L:"..ip..":"..Sp)
	dl(0)
	iSrv()
end
end
end
WD.I()

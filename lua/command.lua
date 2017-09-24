function sM(p,m)
if m==MI then
gM(p,gpio.INPUT)
Dv[p]=-1
elseif m==MO then
gM(p,gpio.OUTPUT)
if Dv[p]~=nil then Dv[p]=nil table.remove(Dv,p) end
elseif m==MP then
pStart(p)
if Dv[p]~=nil then Dv[p]=nil table.remove(Dv,p) end
end
end

function aPW(p1,p2,v)
dp3(2,"aPW",p1,p2,v)
if v>0 then
pDuty(p1,v)
pDuty(p2,0)
elseif v<0 then
pDuty(p1,0)
pDuty(p2,0-v)
else
pDuty(p1,0)
pDuty(p2,0)
end
end

function lVm(v,vm)
if 0<v and v<vm then return 0
elseif -vm<v and v<0 then return 0
end
return v
end

function tW(p1,p2,p3,p4,x,y)
x=x+(cfg.t.xc or 0)
y=y+(cfg.t.yc or 0)
local yxm=""
if y>=0 then yxm="T" else yxm="B" end
if x>=0 then yxm=yxm.."R" else yxm=yxm.."L" end  
local T=TC[yxm.."A"]
local v=(T.d*x*y+T.a*x+T.b*y+T.c)/100
v=lVm(v,cfg.t.vm or 0)
aPW(p1,p2,v)
T=TC[yxm.."B"]
v=(T.d*x*y+T.a*x+T.b*y+T.c)/100
v=lVm(v,cfg.t.vm or 0)
aPW(p3,p4,v)
end

function resetAll()
for p=0,8 do
if Dv[p]== nil then
	if p>0 then pStop(p) end
	gM(p,gpio.OUTPUT)
	gW(p,0)
end
end
end

function getName()
return "name "..cfg.name
end

function readDevice(p)
v=Dv[p]
if type(v)=="number" and v<0 then v=gR(p) end
return v
end

function poll()
local d=""
for p in pairs(Dv) do
	v=readDevice(p)
	if string.len(d)>0 then d=d.."\n" end
	d=d..S(p).." "..S(v)
end
return d
end

function csplit(t,s)
local r={}
local n=1
for w in t:gmatch("([^"..s.."]*)") do
	r[n]=r[n] or w
	if w=="" then n=n+1 end
end
return r
end

function exeCmd(st)
local r=""
P("> "..st)
local cc=csplit(st," ")
if #cc>1 then
	if cfg.name==cc[1] then
		table.remove(cc,1)
	else
		for m,cfg in pairs(MC[WCN]) do
			if cfg.name==cc[1] then
				return r
			end
		end 
	end
end
if #cc==1 then
	local cmd=cc[1]
	if cmd=="reset_all" then
		resetAll()
	elseif cmd=="getName" then
		r=getName()
	elseif cmd=="poll" then
		r=poll()
	end
elseif #cc==2 then
	local cmd=cc[1]
	local p=N(cc[2])
	if cmd=="digitalRead" then
		r=S(p).." "..S(gR(p))
	elseif cmd=="analogRead" then
		r=S(p).." "..S(readDevice(p))
	end
elseif #cc==3 then
	local cmd=cc[1]
	local p=N(cc[2])
	local v=N(cc[3])
	if cmd=="pinMode" then
		sM(p,v)
	elseif cmd=="digitalWrite" then
		gW(p,v)
	elseif cmd=="analogWrite" then
		if v<0 then
			pStop(p)
		else
			pDuty(p,v)
		end
	elseif cmd=="print" then
		oledText(p,cc[3])
	end
elseif #cc==4 then
	local cmd=cc[1]
	local p1=N(cc[2])
	local p2=N(cc[3])
	local v=N(cc[4])
	if cmd=="analogPairWrite" then
		aPW(p1,p2,v)
	end
elseif #cc==7 then
	local cmd=cc[1]
	if cmd=="tankWrite" then
		tW(N(cc[2]),N(cc[3]),N(cc[4]),N(cc[5]),N(cc[6]),N(cc[7]))
	end
else
	P("E: CMD")
end
return r
end

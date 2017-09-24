function init_oled(sda,scl,sla)
i2c.setup(0,sda,scl,i2c.SLOW)
disp=u8g.ssd1306_64x48_i2c(sla)
disp:setFont(u8g.font_6x10)
disp:setFontRefHeightText()
disp:setFontPosBottom()
end

function oledText(p,t)
disp:firstPage()
repeat drawText(t) until disp:nextPage() == false
end

function drawText(t)
t=string.gsub(t,"+"," ")
t=string.gsub(t,"%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)
local s=""
local ls={}
for s in t:gmatch("[^\n]+") do
    while string.len(s)>0 do
		table.insert(ls,s:sub(1,cfg.d.oled.w))
		s=s:sub(cfg.d.oled.w+1)
    end
end
local l=0 
for l=1,#ls do
    disp:drawStr(0,l*12,tostring(ls[l]))
    if l>=cfg.d.oled.h then break end
    l=l+1
end
end
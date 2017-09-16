function WD.iC(dataReceiver)
if cfg.l.p>0 then
print("U:L "..cfg.l.p)
connL=net.createUDPSocket()
connL:listen(cfg.l.p)     
connL:on("receive",dataReceiver) 
end
end

function WD.cC()
print("U:C")
connL=nil
end


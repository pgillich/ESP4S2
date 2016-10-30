-- This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
-- Copyright (C) 2016 pgillich, under GPLv3 license.

function change2mode(pin,mode,oldMode)
  if mode~=oldMode then
    if oldMode==MODE_PWM then
      pwmStop(pin)
    end
  
    if mode==MODE_INPUT then
      gpioMode(pin, gpio.INPUT)
    elseif mode==MODE_OUTPUT then
      gpioMode(pin, gpio.OUTPUT)
    elseif mode==MODE_PWM then
      pwmStart(pin)
    else
      print("ERR: unknown mode, "..tostring(mode))
    end
  end
end

function change2value(pin,mode,val,oldVal)
  if mode==MODE_OUTPUT then
    gpioWrite(pin,val)
  elseif mode==MODE_PWM then
    pwmSetduty(pin,val)
  else
    print("ERR: unknown mode, "..tostring(mode))
  end
end

function pinMode(pin,mode)
  local resp=""
  if type(PINS_state[pin])~=nil and type(PIN_MODES[mode])~=nil then
    print("  pinMode("..tostring(pin)..","..tostring(mode)..")")
    change2mode(pin,mode,PINS_state[pin]["m"])
    PINS_state[pin]["m"]=mode
  end
  return resp
end

function digitalWrite(pin,val)
  local resp=""
  if type(PINS_state[pin])~=nil and PINS_state[pin]["m"]==MODE_OUTPUT then
    if val==0 or val==1 then
      print("  digitalWrite("..tostring(pin)..","..tostring(val)..")")
      change2value(pin, PINS_state[pin]["m"], val, PINS_state[pin]["v"])
      PINS_state[pin]["v"]=val
    end
  else
    print("ERR: invalid digitalWrite("..tostring(pin)..","..tostring(val)..")")
  end
  return resp
end

function analogWrite(pin,val)
  local resp=""
  if type(PINS_state[pin])~=nil and PINS_state[pin]["m"]==MODE_PWM then
    if val>=0 and val<=100 then
      print("  analogWrite("..tostring(pin)..","..tostring(val)..")")
      change2value(pin, PINS_state[pin]["m"], val, PINS_state[pin]["v"])
      PINS_state[pin]["v"]=val
    end
  else
    print("ERR: invalid analogWrite("..tostring(pin)..","..tostring(val)..")")
  end
  return resp
end

function analogPairWrite(pin1,pin2,val)
  local resp=""
  if val>0 then
    resp=resp..analogWrite(pin1,val)
    resp=resp..analogWrite(pin2,0)
  elseif val<0 then
    resp=resp..analogWrite(pin1,0)
    resp=resp..analogWrite(pin2,0-val)
  else
    resp=resp..analogWrite(pin1,0)
    resp=resp..analogWrite(pin2,0)
  end
  return resp
end

function limitVmin(v,v_min)
  if 0<v and v<v_min then
    return 0
  elseif -v_min<v and v<0 then 
    return 0
  end
  return v
end

function tankWrite(pin1,pin2,pin3,pin4,x,y)
  x=x+(config.tank.x_corr or 0)
  y=y+(config.tank.y_corr or 0)
  local resp=""
  local idx=""
  if y>=0 then
    idx=idx.."T"
  else
    idx=idx.."B"
  end
  if x>=0 then
    idx=idx.."R"
  else
    idx=idx.."L"
  end  
  local T=TANK_CONST[idx.."A"]
  local v=(T.d*x*y+T.a*x+T.b*y+T.c)/100
  v=limitVmin(v,config.tank.v_min or 0)
  resp=resp..analogPairWrite(pin1,pin2,v)
  T=TANK_CONST[idx.."B"]
  v=(T.d*x*y+T.a*x+T.b*y+T.c)/100
  v=limitVmin(v,config.tank.v_min or 0)
  resp=resp..analogPairWrite(pin3,pin4,v)
  return resp
end

function resetAll()
  local resp=""
  for pin,mv in pairs(PINS_state) do
    local m=mv["m"]
    local v=mv["v"]
    if type(m)~=nil then
      if m==MODE_OUTPUT then
        resp=resp..digitalWrite(pin,0)
      elseif m==MODE_PWM then
        resp=resp..analogWrite(pin,0)
      end
    end
  end 
  return resp
end

function getName()
  return "name "..config.name
end

function getValue(pin)
  if type(PINS_state[pin])~=nil then
    if pin==0 and PINS_state[pin]["m"]==MODE_ANALOG then
      return adcRead(pin)
    elseif PINS_state[pin]["m"]==MODE_ANALOG then
      readDevices()
      return PINS_state[pin]["v"]
    elseif PINS_state[pin]["m"]==MODE_INPUT then
      return gpioRead(pin)
    end
  end
  return -1
end

function poll()
  local data=""
  readDevices()
  for pin,mv in pairs(PINS_state) do
    local m=mv["m"]
    local v=mv["v"]
    if type(m)~=nil and (m==MODE_INPUT or m==MODE_ANALOG) then
      if string.len(data)>0 then
        data=data.."\n"
      end
      data=data..tostring(pin).." "..tostring(v)
    end
  end
  return data
end

function csplit(str,sep)
  local ret={}
  local n=1
  for w in str:gmatch("([^"..sep.."]*)") do
    ret[n]=ret[n] or w
    if w=="" then n=n+1 end
  end
  return ret
end

function exeCmd(st)
  local resp=""
  print("> "..st)
  local command=csplit(st," ")
  if #command>1 then
    if config.name==command[1] then
      table.remove(command,1)
    else
      for m,cfg in pairs(MAC_config[WIFI_CFG_NAME]) do
        if cfg.name==command[1] then
          return resp
        end
      end 
    end
  end
  if #command==1 then
    local cmd=command[1]
    if cmd=="reset_all" then
      resp=resetAll()
    elseif cmd=="getName" then
      resp=getName()
    elseif cmd=="poll" then
      resp=poll()
    end
  elseif #command==2 then
    local cmd=command[1]
    local pin=tonumber(command[2])
    if cmd=="digitalRead" then
      resp=tostring(pin).." "..tostring(getValue(pin))
    elseif cmd=="analogRead" then
      resp=tostring(pin).." "..tostring(getValue(pin))
    end
  elseif #command==3 then
    local cmd=command[1]
    local pin=tonumber(command[2])
    local val=tonumber(command[3])
    if cmd=="pinMode" then
      resp=pinMode(pin,val)
    elseif cmd=="digitalWrite" then
      resp=digitalWrite(pin,val)
    elseif cmd=="analogWrite" then
      resp=analogWrite(pin,val)
    end
  elseif #command==4 then
    local cmd=command[1]
    local pin1=tonumber(command[2])
    local pin2=tonumber(command[3])
    local val=tonumber(command[4])
    if cmd=="analogPairWrite" then
      resp=analogPairWrite(pin1,pin2,val)
    end
  elseif #command==7 then
    local cmd=command[1]
    if cmd=="tankWrite" then
      resp=tankWrite(tonumber(command[2]),tonumber(command[3]),tonumber(command[4]),tonumber(command[5]),tonumber(command[6]),tonumber(command[7]))
    end
  else
    print("ERR: unknown command")
  end
  return resp
end

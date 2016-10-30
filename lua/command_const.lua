MODE_UNAVAILABLE=-1
MODE_INPUT=0
MODE_OUTPUT=1
MODE_ANALOG=2
MODE_PWM=3
MODE_SERVO=4

PIN_MODES={
  [MODE_UNAVAILABLE]="UNAVAILABLE",
  [MODE_INPUT]="INPUT",
  [MODE_OUTPUT]="OUTPUT",
  [MODE_ANALOG]="ANALOG",
  [MODE_PWM]="PWM",
  [MODE_SERVO]="SERVO"
}

PINS_state={
  [0]={m=-1,v=-1},
  [1]={m=-1,v=-1},
  [2]={m=-1,v=-1},
  [3]={m=-1,v=-1},
  [4]={m=-1,v=-1},
  [5]={m=-1,v=-1},
  [6]={m=-1,v=-1},
  [7]={m=-1,v=-1},
  [8]={m=-1,v=-1},
  [11]={m=-1,v=-1},
  [12]={m=-1,v=-1},
}

TANK_CONST={
  ["TLA"]={a=-100,b=100,c=0,d=1},
  ["TLB"]={a=100,b=100,c=0,d=0},
  ["TRA"]={a=-100,b=100,c=0,d=0},
  ["TRB"]={a=100,b=100,c=0,d=-1},
  ["BLA"]={a=-100,b=100,c=0,d=0},
  ["BLB"]={a=100,b=100,c=0,d=1},
  ["BRA"]={a=-100,b=100,c=0,d=-1},
  ["BRB"]={a=100,b=100,c=0,d=0}
}
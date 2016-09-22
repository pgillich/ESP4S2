# ESP4S2
ESP8266 NodeMCU for MIT Scratch 2

## Introduction
The aim of this project is giving microcontroller control into hand of kids. Scratch or Roboremo can be used as user interface. ESP8266 is a cheap microcontroller with built-in WiFi (SoC). See [IoT for $10](https://prezi.com/j9xhibnr7qbj/iot-for-10/) for a "Hello, World!" example. There are a lot of variants, examples are optimized for [WeMos D1 mini](http://www.wemos.cc/Products/d1_mini.html).

Components:
* ESP8266: microcontroller with built-in WiFi _(required)_
  * NodeMCU firmware _(required)_
  * __Controller__, written in Lua for executing control commands and providing sensor values _(required)_
  * H-bridge _(optional)_
  * HC-SR04 _(optional)_
* Scratch 2 Offline Editor: a programming interface _(optional)_
  * __Bridge__, a Scratch Extension written in Python _(required to Scratch)_
  * Python interpreter _(required to Scratch)_
* Roboremo: a simple manual control interface on Android _(optional)_

Example setups:
```
                                                               +----------+
                                         +--------------+  +-->| HC-SR04  |
                                         |              +--+   +----------+
                                    +--->|  Controller  |
+-----------+        +----------+   |    |              +--+   +----------+
|           |  HTTP  |          +---+    +--------------+  +-->| H-bridge |
|  Scratch  +------->|  Bridge  |  WiFi                        +----------+
|           |        |          +---+    +--------------+
+-----------+        +----------+   |    |              |      +----------+
                                    +--->|  Controller  +----->| H-bridge |
                                         |              |      +----------+
                                         +--------------+


                                                               +----------+
                   +------------+        +--------------+  +-->| H-bridge |
                   |            |  WiFi  |              +--+   +----------+
                   |  RoboRemo  +------->|  Controller  |
                   |            |        |              +--+   +----------+
                   +------------+        +------+-------+  +-->| HC-SR04  |
                                                |              +----------+
                                           WiFi |
                                                V
                                         +--------------+
                                         |              |      +----------+
                                         |  Controller  +----->| H-bridge |
                                         |              |      +----------+
                                         +--------------+

```

## Status
Supported Scratch commands:
- [x] initNet: Initialize WiFi subnet (only one subnet is supported simultaneously), IP address is a sum of subnet address and device id.
- [x] pinMode: NodeMCU command(s): gpio.mode or pwm.setup + pwm.start
- [x] digitalWrite: NodeMCU command(s): gpio.write
- [x] analogWrite: NodeMCU command(s): pwm.setduty
- [x] analogPairWrite: NodeMCU command(s): pwm.setduty
- [ ] tankWrite: NodeMCU command(s): pwm.setduty
- [ ] servoWrite: NodeMCU command(s): gpio.write
- [x] digitalRead: NodeMCU command(s): gpio.read
- [x] analogRead: NodeMCU command(s): adc.read or custom sensor command
- [ ] reset_all: Reset state machine, NodeMCU command(s): gpio.write, pwm.setduty
- [x] poll: 

Bridge Features:
- [x] Supporting more NodeMCUs in one WiFi network
- [x] Command-line parameters
- [x] Overload protection by state machine (only changes are sent to Controller)
- [x] Overload protection by UDP "ACK"
- [x] Overload protection by batch command sending
- [x] Overload protection by rare poll and caching digitalRead/analogRead values
- [ ] Overload protection by queue size limitation (drop) 
- [ ] Unit tests 

Controller Features:
- [x] analogPairWrite: transform a [-100,+100] value to 2 pins of H-bridge for a DC motor 
- [ ] tankWrite: transform a ([-100,+100], [-100,+100]) value pair to pins of H-bridge for 2 DC motor 
- [x] UDP
- [ ] TCP
- [x] Supporting more NodeMCUs in one WiFi network, for Bridge
- [ ] Supporting more NodeMCUs in one WiFi network, for Roboremo (proxy)
- [x] HC-SR04 sensor support
- [ ] DHT sensor support
- [ ] BMP180 sensor support

## Install

### Wiring
[WeMos D1 mini](http://www.wemos.cc/Products/d1_mini.html) system has some additional resistors and dedicated pins for shields. These constraints determine a logical pinout:

| ESP-8266 Pin| Pin | WeMos Function | ESP4S2 Function
| --- | --- | ---  | --- 
| A0     | A0 | Analog input, max 3.3V input | Analog input
| GPIO16 | D0 | IO              | HC-SR04 Trig
| GPIO5  | D1 | IO, SCL         | I2C for shields
| GPIO4  | D2 | IO, SDA         | I2C for shields
| GPIO0  | D3 | IO, 10k Pull-up | H-bridge B2
| GPIO2  | D4 | IO, BUILTIN_LED<br/>10k Pull-up | Blue LED<br/>DHT Data
| GPIO14 | D5 | IO, SCK         | H-bridge A1
| GPIO12 | D6 | IO, MISO        | H-bridge A2
| GPIO13 | D7 | IO, MOSI        | H-bridge B1
| GPIO15 | D8 | IO, SS<br/>10k Pull-down | HC-SR04 Echo<br/>+ 4k7: 5V-->3.3V voltage divider

D8 pin works well with Pololu DRV8833 as B2 input, but activates motor B with cheap L9110 at power on. D3 works well with cheap L9110. I2C pins are used by shields OLED and Motor.

HC-SR04 needs 5V power and Echo pin output is 5V, too (3.3V input is good for Trig). A 4k7 with 10k Pull-down resistor behave as a voltage divider, see: [HC-SR04 Ultrasonic Range Sensor on the Raspberry Pi](http://www.modmypi.com/blog/hc-sr04-ultrasonic-range-sensor-on-the-raspberry-pi).

Other pinout can also be used.

### NodeMCU Firmware
NodeMCU is an embedded Lua firmware to ESP8266. Firmware can be download from [NodeMCU custom builds](https://nodemcu-build.com/) (builds combined binary). For using H-bridge, PWM module must be selected. For using DHT sensor, DHT module must be selected. Integer build must be used.
Firmware can be flashed by esptool.py or NodeMCU Flasher, see [Flashing the firmware](https://nodemcu.readthedocs.io/en/dev/en/flash/). Since 1.5.1-master, default baud switched to 115200.

### Controller
[ESPlorer](http://esp8266.ru/esplorer/) can be used to upload Lua files to ESP.<br/>
Copy ```secure.lua.example``` to ```secure.lua``` and edit own WiFi authentication configuration.<br/>Copy ```config.lua.example``` to ```config.lua``` and edit network configuration. Controller supports more WiFi network configuration, selected by ```WIFI_CFG_NAME```. ESP microcontrollers are identified by its MAC address. STATION and AP mode are supported. In STATION mode (```wifiMode=wifi.STATION```), Controller requests an IP address from a WiFi AP (a WiFi router or an ESP8266 in SOFTAP or STATIONAP mode). If WiFi AP is not alive, ```ip``` parameter will be used. If ```static_ip=true```, Controller enforces ```ip``` as IP address (```netmask``` should be declared, too). In SOFTAP mode (```wifiMode=wifi.SOFTAP```), NodeMCU runs as WiFi AP and WiFi router is not required for WiFi communication. Other Controllers in this WiFi network should be configured with static IP address (```static_ip=true```). Devices with custom feature can be configured in ```devices```.<br/>
Upload all ```*.lua``` files of directory ```lua``` to NodeMCU. After reset, NodeMCU will be ready to receive commands and send back input values.

### Bridge

### Roboremo

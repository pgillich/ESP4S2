ESP4S2 is a project on ESP8266 NodeMCU with control by MIT Scratch 2 or RoboRemo.

* [Introduction](#introduction)
   * [Feature List](#feature-list)
   * [Device and Sensor Extensions](#device-and-sensor-extensions)
      * [ADC](#adc)
      * [HC-SR04](#hc-sr04)
      * [DHT](#dht)
      * [BMP](#bmp)
      * [OLED](#oled)
* [Installation and Configuration](#installation-and-configuration)
   * [Getting Repository](#getting-repository)
   * [Wiring](#wiring)
   * [NodeMCU Firmware](#nodemcu-firmware)
   * [Controller](#controller)
      * [Configuration](#configuration)
      * [Uploading files](#uploading-files)
      * [Socat](#socat)
   * [Bridge](#bridge)
      * [Windows install](#windows-install)
      * [Cygwin install](#cygwin-install)
      * [Linux install](#linux-install)
   * [Scratch](#scratch)
      * [Scratch 2 Offline Editor](#scratch-2-offline-editor)
      * [ScratchX](#scratchx)
   * [RoboRemo](#roboremo)
      * [Single Controller](#single-controller)
      * [Multiple Controllers](#multiple-controllers)
* [Programer's Guides](#programers-guides)
   * [Scratch Beginner Programer's Guide](#scratch-beginner-programers-guide)
      * [First steps](#first-steps)
      * [Blocks](#blocks)
   * [Sample projects](#sample-projects)
      * [LED project](#led-project)
      * [PWM project](#pwm-project)
      * [DC motor project](#dc-motor-project)
   * [Scratch Advanced Programer's Guide](#scratch-advanced-programers-guide)
   * [Controller Command Reference](#controller-command-reference)
      * [Get Controller Name](#get-controller-name)
      * [Set Pin Mode](#set-pin-mode)
      * [Digital Read](#digital-read)
      * [Digital Write](#digital-write)
      * [PWM Write](#pwm-write)
      * [Stop PWM](#stop-pwm)
      * [PWM Pair Write](#pwm-pair-write)
      * [Tank Write](#tank-write)
      * [Servo Write](#servo-write)
      * [Print](#print)
      * [Analog Read](#analog-read)
      * [Poll](#poll)
      * [Reset All](#reset-all)


# Introduction

The aim of this project is giving microcontroller control into hands of kids. The solution is inspired by [A4S](https://github.com/damellis/A4S) and [Firmata](https://github.com/firmata/protocol). Scratch or RoboRemo can be used as user interface. ESP4S2 is licensed under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
Please read [LICENSE](LICENSE). TOC is created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc).

ESP8266 is a cheap microcontroller with built-in WiFi (SoC). See [IoT for $10](https://prezi.com/j9xhibnr7qbj/iot-for-10/) to execute a "Hello, World!" example. There are a lot of variants, below examples are optimized for [WeMos D1 mini](https://wiki.wemos.cc/products:d1:d1_mini).

Hardware instructions for WeMos D1 mini and tank example are described at [instructables.com](http://www.instructables.com/id/Controlling-LEGO-Tank-by-ESP8266-With-Scratch-or-R/):
![Controlling LEGO Tank by ESP8266 With Scratch or RoboRemo](https://cdn.instructables.com/FI2/M1QL/IU9US0HZ/FI2M1QLIU9US0HZ.MEDIUM.jpg)

Software Components:
* ESP8266: microcontroller with built-in WiFi _(required)_
  * NodeMCU firmware _(required)_
  * __Controller__, written in Lua for executing control commands and providing sensor values _(required)_
  * H-bridge _(optional)_
  * sensors, for example: HC-SR04, DHT, BMP, OLED _(optional)_
* Scratch 2: a programming interface _(optional)_
  * __Bridge__, a Scratch Extension written in Python _(required to Scratch)_
  * Python interpreter _(required to Scratch)_
* Roboremo: a simple manual control interface on Android _(optional)_

[Scratch 2.0 Offline Editor](https://wiki.scratch.mit.edu/wiki/Scratch_2.0_Offline_Editor) and [ScratchX](http://scratchx.org) are both supported.

Example setups:
```
                                                                    +----------+
+-------------------------------------+       +--------------+  +-->| HC-SR04  |
|            Desktop, Laptop          |       |              +--+   +----------+
|                                     |  +--->|  Controller  |
|  +-----------+        +----------+  |  |    |              +--+   +----------+
|  |           |  HTTP  |          +-----+    +--------------+  +-->| H-bridge |
|  |  Scratch  +------->|  Bridge  |  | WiFi                        +----------+
|  |           |        |          +-----+    +--------------+
|  +-----------+        +----------+  |  |    |              |      +----------+
|                                     |  +--->|  Controller  +----->| H-bridge |
|                                     |       |              |      +----------+
+-------------------------------------+  UDP  +--------------+


                   +------------------+
                   |  Tablet, Phone   |
                   |                  |                             +----------+
                   |  +------------+  |       +--------------+  +-->| H-bridge |
                   |  |            |  | WiFi  |              +--+   +----------+
                   |  |  RoboRemo  +--------->|  Controller  |
                   |  |            |  |       |              +--+   +----------+
                   |  +------------+  |  UDP  +--------------+  +-->| HC-SR04  |
                   |                  |                             +----------+
                   |                  |       
                   +------------------+              


                                                                    +----------+
                   +------------------+       +--------------+  +-->+ HC-SR04  |
                   |  Tablet, Phone   |       |              +--+   +----------+
                   |                  |  +--->+  Controller  |
                   |  +------------+  |  |    |              +--+   +----------+
                   |  |            +-----+    +--------------+  +-->+ H-bridge |
                   |  |  RoboRemo  |  | WiFi                        +----------+
                   |  |            +-----+    +--------------+
                   |  +------------+  |  |    |              |      +----------+
                   |                  |  +--->+  Controller  +----->+ H-bridge |
                   |                  |  UDP  |              |      +----------+
                   +------------------+ broad +--------------+
                                        -cast

```

## Feature List
Supported Scratch commands:
- [x] `Set network` (`initNet`): Initialize WiFi subnet (only one subnet is supported simultaneously), IP address is a sum of subnet address and device id.
- [x] `set pin` (`pinMode`): NodeMCU command(s): `gpio.mode` or `pwm.setup` + `pwm.start`
- [x] `digital write pin` (`digitalWrite`): NodeMCU command(s): `gpio.write`
- [x] `analog write pin` (`analogWrite`): NodeMCU command(s): `pwm.setduty`
- [x] `analog write pin pair` (`analogPairWrite`): NodeMCU command(s): `pwm.setduty`
- [x] `tank write pin pair` (`tankWrite`): NodeMCU command(s): `pwm.setduty`
- [ ] `servo write pair` (`servoWrite`): NodeMCU command(s): `gpio.write`
- [x] `print text` (`servoWrite`): NodeMCU command(s): `u8g:drawStr`
- [x] `digital read pin` (`digitalRead`): NodeMCU command(s): `gpio.read`
- [x] `analog read pin` (`analogRead`): NodeMCU command(s): `adc.read` or custom sensor command
- [x] ![Stop](doc/stop-sign-small.png) (`reset_all`): Reset state machine, NodeMCU command(s): `gpio.write`, `pwm.setduty`
- [x] `poll`: return cached values of `digitalRead`, `analogRead`
- [ ] Simplified Block commands

Bridge Features:
- [x] Supporting more NodeMCUs in one WiFi network
- [x] Command-line parameters
- [x] Overload protection by state machine (only changes are sent to Controller)
- [x] Overload protection by UDP "ACK" (waiting for processing the earlier sent command, +timeout)
- [x] Overload protection by batch command sending (programmatically configured)
- [x] Overload protection by rare poll and caching digitalRead/analogRead values
- [ ] Overload protection by queue size limitation (drop) 
- [x] Name resolution (instead of IP address) 
- [ ] Simplified Block commands
- [ ] Unit tests 

Controller Features:
- [x] Basic digital pin handling (mode, high/low, PWM)
- [ ] `analogRead`: `adc.read` reads value to a pseudo pin
- [x] `analogPairWrite`: transforms a [-100,+100] value to 2 pins of H-bridge for a DC motor 
- [x] `tankWrite`: transforms a joystick XY value pair ([-100,+100], [-100,+100]) to A-B pins of H-bridge for 2 DC motor 
- [x] Stop PWM on a pin, if value is -1 (`analog write pin -1`)
- [x] `getName`: returns Controller name 
- [ ] Too small PWM value is overwritten to 0 (for DC motors)
- [x] Too small PWM value is overwritten to 0 (for tank)
- [x] WiFi station and AP mode
- [x] MAC-based configuration
- [x] Configuration for more networks
- [x] State check for pin mode 
- [ ] Automatic pin mode 
- [x] UDP
- [ ] Send values back to RoboRemo
- [ ] TCP
- [ ] HTTP
- [x] Supporting more NodeMCUs in one WiFi network, for Bridge
- [x] Supporting more NodeMCUs in one WiFi network, for RoboRemo (UDP broadcast)
- [x] HC-SR04 sensor support
- [x] DHT sensor support
- [x] BMP180 sensor support
- [x] OLED support

## Device and Sensor Extensions

### ADC

Using NodeMCU [ADC Module](http://nodemcu.readthedocs.io/en/master/en/modules/adc/). Only A0 pin is supported.

Required NodeMCU modules: `adc`

### HC-SR04

Original source from: [node_hcsr04](https://github.com/sza2/node_hcsr04). Main change: replacing tmr.delay to tmr.alert. Optimized for [WeMos D1 mini](https://wiki.wemos.cc/products:d1:d1_mini). Sensor pins:
- ECHO: D8 (GPIO15) pulled down by 10k (R2) on WeMos D1 mini. R1 between ECHO and D8 as voltage divider: 4k7, see more:
 [HC-SR04 Ultrasonic Range Sensor on the Raspberry Pi](http://www.modmypi.com/blog/hc-sr04-ultrasonic-range-sensor-on-the-raspberry-pi)
- TRIG: D0 (GPIO16). Can only be used as gpio read/write. No support for open-drain/interrupt/pwm/i2c/ow.
- VCC: 5V
- GND: G

Trig time: min. 10 us. Max echo time: 38 ms. Usage: `dofile("hcsr.lua") device=hcsr.init() device.start()`, automatically called by `init.lua`, if `devices["hcsr"]` in `config.lua` is set properly.

### DHT

Using NodeMCU [DHT module](http://nodemcu.readthedocs.io/en/master/en/modules/dht/). Suggested pin for WeMos shield is: D4. Uses [dht.read()](http://nodemcu.readthedocs.io/en/master/en/modules/dht/#dhtread), which supports several kind of DHT sensors.

Required NodeMCU modules: `dht`

### BMP

Using NodeMCU [BMP085 Module](http://nodemcu.readthedocs.io/en/master/en/modules/bmp085/). Suggested pins for WeMos are the WeMos I2C pins (D1, D2). It supports BMP-085 and BMP-180.

Required NodeMCU modules: `bmp085`, `i2c`

### OLED

Using NodeMCU [u8g Module](http://nodemcu.readthedocs.io/en/master/en/modules/u8g/). Works with WeMos [OLED Shield](https://wiki.wemos.cc/products:d1_mini_shields:oled_shield) (ssd1306_64x48_i2C).

Required NodeMCU modules: `u8g`, `i2c`, see [OLED Shield documentations](https://wiki.wemos.cc/products:d1_mini_shields:oled_shield#nodemcu_code)

# Installation and Configuration

## Getting Repository
Clone or download and extract repository from [GitHub](https://github.com/pgillich/ESP4S2). It can be downloaded as a zip file, or can have by a Git command, for example:
```
git clone https://github.com/pgillich/ESP4S2.git
```

## Wiring
[WeMos D1 mini](https://wiki.wemos.cc/products:d1:d1_mini) system has some additional resistors and dedicated pins for shields, see [D1 mini Schematic](https://wiki.wemos.cc/_media/products:d1:mini_new_v2_2_0.pdf). These constraints determine a logical pinout:

| ESP-8266 Pin| Pin | WeMos Function | suggested ESP4S2 Function
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

D8 pin works well with Pololu DRV8833 as B2 input, but activates motor B with cheap L9110 at power on. D3 works well with cheap L9110. I2C pins are used by WeMos shields [OLED](https://wiki.wemos.cc/products:d1_mini_shields:oled_shield) and [DC Power](https://wiki.wemos.cc/products:d1_mini_shields:dc_power_shield).

HC-SR04 needs 5V power, Echo pin output is 5V, too (3.3V input is good for Trig). An additional 4k7 resistor with built-in 10k Pull-down resistor behave as a voltage divider, see: [HC-SR04 Ultrasonic Range Sensor on the Raspberry Pi](http://www.modmypi.com/blog/hc-sr04-ultrasonic-range-sensor-on-the-raspberry-pi).

Pin D4 is used by WeMos [D1 mini Shields](https://wiki.wemos.cc/products:d1_mini_shields), for example [DHT Shield(Retired)](https://wiki.wemos.cc/products:retired:dht_shield_v1.0.0).

Other pinout can also be used.

## NodeMCU Firmware
NodeMCU is an embedded Lua firmware to ESP8266. Firmware can be download from [NodeMCU custom builds](https://nodemcu-build.com/) (builds combined binary). For using PWM (for example: H-bridge), `pwm` module must be selected. Depending on applied sensors, more modules should be selected. Integer build must be downloaded.
Firmware can be flashed by esptool.py or NodeMCU Flasher, see [Flashing the firmware](https://nodemcu.readthedocs.io/en/dev/en/flash/). For old boards, esptool.py might be more stable. Since 1.5.1-master, default baud is 115200 (instead of 9600).

## Controller

### Configuration

Security configuration is stored in `secure.lua`. Be very careful about information stored in this file. 

Copy `secure.lua.example` to `secure.lua` and edit own WiFi authentication configuration.  Structure of `secure.lua`:

* `WC`
  * User-friendly name of network profile 
    * `ssid`
    * `pwd`
    * any other key supported by NodeMCU `wifi` module, described at [wifi.ap Module](https://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifiapconfig), for example `auth` is required for AP.

Other configurations are stored in config.lua. Controllers are identified by its MAC address. STATION and AP mode are supported. In STATION mode (`wM=wifi.STATION`), Controller requests an IP address from a WiFi AP (can be a WiFi router or an ESP8266 in SOFTAP or STATIONAP mode). If WiFi AP is not alive, `ip` parameter will be used. If `ipS=true`, Controller enforces `ip` as IP address (`netmask` should be and `gateway` might be declared, too, see [wifi.sta.setip](http://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifistasetip) ). In SOFTAP mode (`wM=wifi.SOFTAP`), NodeMCU runs as WiFi AP and WiFi router is not required for WiFi communication. Other Controllers in this WiFi network should be configured with static IP address (`ipS=true`). 

Copy `config.lua.example` to `config.lua` and edit network configuration. Structure of `config.lua`:

* `WCN`: User-friendly name of active network profile. Other network profiles will be cleaned in runtime.
* `RRP`: RoboRemo port (listening port)
* `DL`: Debug led. If it's non-zero, it blinks during initialization and network communications.
* `WPM`: WiFi physical mode, see: [wifi.setphymode](https://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifisetphymode)
* `MC`: Configuration for each Controller
   * User-friendly name of network profile
     * MAC address without `:` separator (can print by command `=wifi.sta.getmac()`)
       * `name`: Controller name, used as device name in Scratch blocks
       * `wM`: WiFi mode, see [wifi.setmode](https://nodemcu.readthedocs.io/en/master/en/modules/wifi/#wifisetmode)
       * `ip`: IP address in AP mode or in static IP forcing or failsafe mode
       * `ipS`: Activates static IP forcing (only in `wifi.STATION` mode)
       * `netmask`: IP netmask
       * `nT`: Networking type (onyl net.UDP is supported)
       * `l`: Listener
         * `p`: Listening port (receiving)
         * `s`: Sending response to port (transmitting)
       * `d`: Device (sensor) configurations, see later
       * `t`: Tank configurations (tank write)
         * `xc`: X correction (RoboRemo)
         * `yc`: Y correction (RoboRemo)
         * `vm`: Value min (lower will be 0)

Device (sensor) configuration can be set at section `MC`._NetProfile.MAC_.`d` of file `config.lua`. Most of devices (sensors) are polled by a timer (except HC-SR), called `tmr`, which also must be configured. Structure of device section:
  * `d`: Device (sensor) configurations
    * `tmr`: Timer for device polling (except HC-SR)
      * `tid`: Timer id, see: [tmr.alarm](https://nodemcu.readthedocs.io/en/master/en/modules/tmr/#tmralarm)
      * `tms`: Timer interval in milliseconds
    * `hdt`: DHT sensor
      * `p`: Pins
        * Data pin, reporting temperature
        * Pseudo pin for reporing humidity
    * `bmp085`: Pressure sensor
      * `p`: I2C pins
        * SDA, reporting temperature
        * SCL, reporting pressure
      * `o`: Oversampling, see: [bmp085.pressure](https://nodemcu.readthedocs.io/en/master/en/modules/bmp085/#bmp085pressure)
    * `oled`: OLED display
      * `p`: I2C pins
        * SDA, reporting temperature
        * SCL, reporting pressure
      * `sla`: I2C address, see: WeMos [OLED Shield](https://wiki.wemos.cc/products:d1_mini_shields:oled_shield)
      * `w`: display width in character
      * `h`: display height in character 
    * `hcsr`: HC-SR sensor
      * `p`: Pins
        * Trig, reporting time
        * Echo, reporting distance
      * `a`: Absorber (higher is stronger)
      * `tid`: Timer id
      * `tms`: Timer interval in milliseconds
    * `adc`: A/D converter on pin A0
      * `p`: Pins
        * Pseudo pin for reporting

Pseudo pins must be higher than 12.

### Uploading files
[ESPlorer](http://esp8266.ru/esplorer/) can be used to upload Lua files to ESP. Upload all `*.lua` files of directory `lua` to NodeMCU. After reset, NodeMCU will be ready to receive commands and send back input values.

### Socat
`socat` can be used for testing Controller without any GUIs (Scratch, RoboRemo). Socat can be installed on Cygwin and Linux. Anoter famous program, `nc` (Netcat), can also send UDP messages, but cannot send from and receive to same port.

Example for sending commands to a specific IP address (Scratch use case):
``` 
socat readline UDP4-DATAGRAM:192.168.10.102:9876,bind=:9877
getName
pinMode 4 1
digitalWrite 4 0
digitalWrite 4 1
```

Example for sending commands to broadcast address (RoboRemo use case):
``` 
socat readline UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877
getName
tank-tower pinMode 4 1
tank-tower digitalWrite 4 0
tank-tower digitalWrite 4 1
```

There are several online portals, where broadcast address can be calculated, for example: [IP Subnet Calculator](http://www.subnet-calculator.com/). 

## Bridge
Bridge is required for Scratch 2. It makes simple overload protection on ESP devices. It makes sure, only one request is executed in same time. High-frequency polling by Scratch 2 HTTP Extension (1/30 s) is also eliminated. Batch command sending is supported.  

Bridge requires Python 2.7. Python `netaddr` is also required. Depending on the OS, install can be different, for example:
```
pip install netaddr
sudo apt-get install python-netaddr
```

Bridge command line options will be printed out by `--help` parameter. Bridge listening port can be set by `--esp-listen-port`, its default value is `9877`. Controllers port can be set by `--esp-port`, its default value is `9876`.

### Windows install
Python 2.7 can be downloaded and installed from [Python Releases for Windows](https://www.python.org/downloads/windows/). Example for starting Bridge:

`C:\Python27\python.exe -c src\ESP4S2.py`

### Cygwin install
Pyton 2.7 package can be installed to [Cygwin](https://www.cygwin.com/), including `pip`, which is required to install `netaddr`. Example for starting Bridge:

`src/ESP4S2.py`

### Linux install
Pyton 2.7 package installation is described at the Linux distributor. Example for starting Bridge:

`src/ESP4S2.py`

## Scratch
Scratch 2.0 Offline Editor and ScratchX are supported. Both of them need __Bridge__. 

### Scratch 2 Offline Editor
[Scratch 2 HTTP Extension](https://wiki.scratch.mit.edu/wiki/HTTP_Extension#HTTP_Extensions) is supported.

Install [Scratch 2 Offline Editor](https://scratch.mit.edu/scratch2download). Import ESP42S extension description `src/ESP4S2.s2e` (shift-click on "File" and select "Import Experimental Extension" from the menu). The new extension blocks will be appeared in the More Blocks palette.

### ScratchX
ScratchX [Javascript Extension](https://github.com/LLK/scratchx/wiki) is supported. Scratch Device Plugin ( [Scratch Extensions Browser Plugin](https://scratch.mit.edu/info/ext_download) ) is not required.

Open ScratchX link with reference to this extension: http://scratchx.org/?url=https://pgillich.github.io/ESP4S2/js/extension.js .

It's possible to provide this extension locally, using a simple HTTP server. Example for running local HTTP web server from parent of cloned Git repository:

`ESP4S2/src/CorsHTTPServer.py 80`

In this case, the ScratchX link should be like:
http://scratchx.org/?url=http://localhost/ESP4S2/js/extension.js

It is possible to provide ScratchX locally (offline). In order to achieve it, ScratchX Git repository must have, example for cloning:
```
git clone https://github.com/LLK/scratchx.git
cd scratchx
python -m SimpleHTTPServer
```
In this case, the ScratchX link should be like:
http://localhost:8000/?url=http://localhost/ESP4S2/js/extension.js

## RoboRemo
[RoboRemo](http://www.roboremo.com) can be installed for Android by [Google Play](https://play.google.com/store/apps/details?id=com.hardcodedjoy.roboremo). Commands are described in the chapter [Controller Command Reference](#controller-command-reference).

### Single Controller
To connect RoboRemo to Controller, use "Internet (UDP)" connection. Example for a connection string: `192.168.10.102:9876`, where the ip and port was set up in `lua/config.lua`.  
A button should be created for initialize pins. Example init button configuration for a H-bridged DC motor on pins 5, 6 and a LED on pin 4:
* set press action (`\n` is also supported instead of Enter): 
```
pinMode 4 1
pinMode 5 3
pinMode 6 3
```
* repeat: delay, period = `0`, `only press action`

Example on/off button configuration for a LED on pin 4:
* set press action: `digitalWrite 4 1` or `digitalWrite 4 0`, depending on a pull-up resistor of the pin. 
* repeat: delay, period = `0`, `only press action`

Example slider for a H-bridged DC motor on pins 5, 6:
* set id: `analogPairWrite 5 6`
* set min, max: min = `-100`, max = `100`
* send when released (tricky: `send when move` should be seen)
* set repeat period: `500` ms

### Multiple Controllers
RoboRemo cannot connect to multiple IP addresses. In this case, the boradcast IP address of subnet can be used. For example, if the subnet is 192.168.10.0/24, the broadcast address is 192.168.10.255. There are several online portals, where broadcast address can be calculated, for example: [IP Subnet Calculator](http://www.subnet-calculator.com/). The command sending to this address will be received by all of Controllers. The target Controller name must be marked by the beginning of the command, for example: `tank-tower pinMode 4 1`, `tank-tower digitalWrite 4 0`, `tank-tower digitalWrite 4 1`. Without marking the Controller name, all Controllers will execute the command. 

# Programer's Guides

## Scratch Beginner Programer's Guide

Below sections describe Scratch blocks and provides a few example projects.

### First steps
After starting Bridge (`src/ESP4S2.py`) and Scratch with extension, it is ready to create block programs. The first block which must be executed is the `Set network` (only once). This block initializes Bridge and requests Controllers to send its names back for name resolution. Example for `Set network` block: ![initNet](doc/initNet.jpg), where `192.168.10.0` is the subnet ID and `24` is the subnet mask bits. There are several online portals, where subnet ID and subnet mask bits can be calculated, for example: [http://www.subnet-calculator.com/](IP Subnet Calculator). At least one second must be wait to collect responses from Controllers, for example: ![wait1s](doc/wait1s.jpg).

### Blocks
Pin mode must be set before using a pin (`set pin`). A block can be executed immediately (`E`) or with the next (`W`). More blocks can be bundled to one group until the first `E` block. The last block of execution bundle must be `E`. Examples for bundled blocks:
* ![pinMode_tank-tower](doc/pinMode_tank-tower.jpg)
* ![pinMode_tank-chassis](doc/pinMode_tank-chassis.jpg)

The simplest control block is the `digital write pin`. See examples for controlling WeMos built-in led:
* ![digitalWrite_high](doc/digitalWrite_high.jpg)
* ![digitalWrite_low](doc/digitalWrite_low.jpg)

PWM can be controlled by block `analog write pin`, for example: ![analogWrite](doc/analogWrite.jpg). Sending -1 will stop PWM on the pin.

H-bridged DC motors can be controlled by `analog write pin pair` block, for example: ![analogPairWrite](doc/analogPairWrite.jpg). The value must be set in interval [-100, 100].

Two H-bridged DC motors can be controlled by `tank write pin quad` block, for example: ![tankWrite](doc/tankWrite.jpg). Four pins and XY values (joystick) must be set in interval [-100, 100]. Controller transforms XY values to A-B values.

Text can be printed on display by block `print text`, for example: ![printOled](doc/printOled.png).

Values can be used by blocks `digital read pin` and `analog read pin`, for example:
* ![digitalRead](doc/digitalRead.jpg)
* ![analogRead_cycle](doc/analogRead_cycle.jpg)

## Sample projects 
Sample projects are located in `project` directory. The Scratch 2 Offline Editor can read `sb2` files, ScratchX can read `sbx` files.

### LED project
It's the "Hello, World!" example of microcontroller world. Built-in blue LED of WeMos is connected to pin `4`. Because of built-in pull-up resistor, LED behaves opposite. After starting Controller and Bridge, please create the below project:

![LED](doc/led.jpg)

Click once on `Set network`. The `192.168.10.0/24` network will be used for communicating to Bridges. It will be valid until Brigde running. Depending on the network setup (WiFi router, ESP AP), the network can be different.

Click on ![Start](doc/green-flag.png). Block `set pin` will set pin `4` to OUTPUT.

When `o` key pressed, pin 4 will be set Low (`0`). Because of built-in pull-up resistor, LED will be turned on. When `x` key pressed, pin 4 will be set High (`1`). Because of built-in pull-up resistor, LED will be turned off.

Click on ![Stop](doc/stop-sign-small.png) to stop all pins.

### PWM project
This project demonstrates PWM. Because of built-in pull-up resistor on pin `4`, LED behaves opposite: it will ligth strongest by setting PWM duty cycle to 0% and LED will be turned off by setting PWM duty cycle 100%. After starting Controller and Bridge, please create the below project:

![PWM](doc/pwm.jpg)

Click once on `Set network`. It will be valid until Brigde running.

Click on ![Start](doc/green-flag.png). Block `set pin` will set pin `4` to PWM.

Press keys 0, 1, 2, 3, 4 to try PWM duty cycles 0%, 50%, 80%, 95%, 100%.

Click on ![Stop](doc/stop-sign-small.png) to stop all pins.

### DC motor project
This project demonstrates DC motor control using PWM and H-bridge. 

## Scratch Advanced Programer's Guide


## Controller Command Reference

A command can be sent to one Controller or to all Controllers, using broadcast address. In this case, the Controller name must be specified before the command. General syntax of commands is:

```[controller-name ]commandName[ option1[ option2[ option3[...]]]```

Endline (`\n`) is required at the end of command. Controller name can be set in `config.lua`.

### Get Controller Name

Command `getName` returns Controller name. This feature is used for Scratch for name resolution. Practically, it should be sent to broadcast address. Example:

```echo "getName" | socat STDIO UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877```

### Set Pin Mode

Command `pinMode` initializes pin. The below modes are supported:
* `0`: INPUT, called NodeMCU command: `gpio.mode(pin, gpio.INPUT)`
* `1`: OUTPUT, called NodeMCU command: `gpio.mode(pin, gpio.OUTPUT)`
* `2`: Analog input. If pin `0`, `adc.read` will be called later, otherwise, a sensor driver can store integer value on this pin.
* `3`: PWM, called NodeMCU commands: `pwm.setup(pin,1000,0)`, `pwm.start(pin)`
* `4`: Servo, not supported yet.

Command syntax is: `pinMode <pin> <mode>`. Example for set pin `4` mode to OUTPUT using single IP address and broadcast address:

```echo "pinMode 4 1" | socat STDIO UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877```

```echo "tank-chassis pinMode 4 1" | socat STDIO UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877```

### Digital Read

Command `digitalRead` reads digital GPIO pin value. It calls `gpio.read(pin)` and returns by the given level. Before executing this command, pin mode must be set to INPUT. Command syntax is: `digitalRead <pin>`. Example for set pin `3` mode to INPUT and reading pin level:

``` 
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 3 0
digitalRead 3
```

### Digital Write

Command `digitalWrite` sets digital GPIO pin value. It calls `gpio.write(pin, level)`. Before executing this command, pin mode must be set to OUTPUT. Command syntax is: `digitalWrite <pin> <level>`. Example for set pin `4` mode to OUTPUT and set its level to gpio.LOW and gpio.HIGH:

``` 
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 4 1
digitalWrite 4 0
digitalWrite 4 1
```

### PWM Write

Command `analogWrite` sets duty cycle for a pin, duty interval is [`0`,`100`]. It calls `pwm.setduty(pin, duty)`. Before executing this command, pin mode must be set to PWM. Command syntax is: `analogWrite <pin> <duty>`. Example for set pin `4` mode to PWM and set duty cycle to `50` and `100`:

``` 
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 4 3
analogWrite 4 50
analogWrite 4 100
```

### Stop PWM

Before using a PWM-mode pin in other mode, PWM clock must be stopped. It can be achieved by sending `-1` to the pin by `analogWrite`. It calls `pwm.stop(pin)` and `pwm.close(pin)`. Example for stop PWM on pin `4`:

```
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 4 3
analogWrite 4 50
analogWrite 4 -1
```

### PWM Pair Write

Command `analogPairWrite` sets duty cycle for 2 pins of a H-bridged DC motor, duty interval is [`-100`,`100`]. If the duty is negative, DC motor will turn reverse. In simple case, it calls `pwm.setduty(pin1, duty)` and `pwm.setduty(pin2, 0)`. If the value is negative, the polarity should be changed, so `pwm.setduty(pin1, 0)` and `pwm.setduty(pin2, 0-duty)` will be called. Before executing this command, pin mode must be set to PWM both on 2 pins. Command syntax is: `analogWrite <pin1> <pin2> <duty>`. Example for set pins `5` and `6` mode to PWM and set duty cycle to 50 and -50 (reverse turn):

``` 
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 5 3
pinMode 6 3
analogPairWrite 5 6 50
analogPairWrite 5 6 -50
```

### Tank Write

Command `tankWrite` transforms a joystick XY value pair ([-100,+100], [-100,+100]) to A-B pins of H-bridge for 2 DC motor. The command calls `pwm.setduty(pin, duty)` on each 4 pins. Before executing this command, pin mode must be set to PWM both on 4 pins. Command syntax is: `tankWrite <pinA1> <pinA2> <pinB1> <pinB2> <x> <y>`. Example for set pins `5`, `6`, `7`, `3` mode to PWM and set x and y values to drive forward, right and turn left in place:

``` 
socat readline UDP4-DATAGRAM:192.168.10.103:9876,bind=:9877
pinMode 5 3
pinMode 6 3
pinMode 7 3
pinMode 3 3
tankWrite 5 6 7 3 0 100
tankWrite 5 6 7 3 100 100
tankWrite 5 6 7 3 -100 0
```

### Servo Write

Not supported yet.

### Print

Command `print` draws given text on the display. It calls `u8g:drawStr`. Command syntax is: `print <id> <text>`. The parameter `id` parameter will be used for identify more displays in the future, currently it's skipped. The parameter `text` is an url-encoded text (UTF-8 is not supported). Endline (`\n`) is supported only by ScratchX. Example for printing a multiline text:

```
socat readline UDP4-DATAGRAM:192.168.10.105:9876,bind=:9877
print 0 Hello%0aWORLD!
```

### Analog Read

Command `analogRead` reads integer values on pins. If pin is `0`, `adc.read(0)` will be called, otherwise, returns sample value of custom sensor driver. Pin mode (`pinMode`) should not called on the pin. Command syntax is: `analogRead <pin>`. Example for getting sensor sample configured on pin `8`:

```echo "analogRead 8" | socat STDIO UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877```

### Poll

Command `poll` returns all cached `digitalRead` and `analogRead` values. Example for getting all cached values:
  
```echo "poll" | socat STDIO UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877```

### Reset All

Command `reset_all` resets output pins to `0`. It calls `pwm.stop(pin)`, `pwm.close(pin)`, `gpio.mode(pin,gpio.OUTPUT)`, `gpio.write(pin,0)` on all non-read and non-device pins. Example for sending reset:
  
```echo "reset_all" | socat STDIO UDP4-DATAGRAM:192.168.10.255:9876,bind=:9877```

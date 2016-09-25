#!/usr/bin/python

# This file is part of ESP4S2. ESP4S2 is a bridge between MIT Scratch 2 and ESP8266 Lua.
# Copyright (C) 2016 pgillich
#
#     ESP4S2 is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     ESP4S2 is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with ESP4S2. If not, see <http://www.gnu.org/licenses/>.

import sys
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
import socket
import time
from netaddr import IPNetwork, IPAddress
import threading
import Queue
import argparse
import re
import pprint


class EspConfig(object):

    def __init__(self):
        self.param = {
            "SCRATCH_IP": "127.0.0.1",
            "SCRATCH_PORT": 58266,
            "ESP_PORT": 9876,
            "ESP_LISTEN_IP": "",
            "ESP_LISTEN_PORT": 9877,
            "ESP_BUFFER": 1024,
            "ESP_PRECISION": 0.001,
            "ESP_ACK_TIMEOUT": 0.200,
            "ESP_POLL_INTERVAL": 0.500,
            "ESP_POLL_CMD": "poll",
            "ESP_FORCE_ACK_DEBUG": False,
            "ESP_POLL_NL": 64,
        }

        self.const = {
            # Pin modes.
            # except from UNAVAILABLE taken from Firmata.h
            "UNAVAILABLE": -1,
            "INPUT": 0,          # as defined in wiring.h
            "OUTPUT": 1,         # as defined in wiring.h
            "ANALOG": 2,         # analog pin in analogInput mode
            "PWM": 3,            # digital pin in PWM output mode
            "SERVO": 4,          # digital pin in SERVO mode
            # Pin digit values
            "LOW": 0,
            "HIGH": 1,
            # Response to Scratch
            "RESPONSE_OK": "okay"
        }

        self.name2id = {}
        self.id2name = {}

        self.name_value_re = re.compile(r"^name ([\w-]*)|;name ([\w-]*)")

        self.processOptions()

        self.code_to_mode = {
                self.UNAVAILABLE: "UNAVAILABLE",
                self.INPUT:  "Digital%20Input",
                self.OUTPUT: "Digital%20Output",
                self.ANALOG: "Analog%20Input",
                self.PWM:    "Analog%20Output(PWM)",
                self.SERVO:  "Servo"
            }
        self.mode_to_code = {}
        for c, m in self.code_to_mode.iteritems():
            self.mode_to_code[m] = c

        self.ipNetwork = None
        self.espHandlersByDevice = {}
        self.espHandlersByIp = {}
        self.lastCmdTs = -1

    def processOptions(self):
        optionParser = argparse.ArgumentParser(description="ESP4S2 options",
                                               formatter_class=argparse.ArgumentDefaultsHelpFormatter)

        optionParser.add_argument("--scratch-ip", default=self.SCRATCH_IP, type=str, dest="SCRATCH_IP",
                                  help="Listening address for Scratch")
        optionParser.add_argument("--scratch-port", default=self.SCRATCH_PORT, type=int, dest="SCRATCH_PORT",
                                  help="Listening port for Scratch")
        optionParser.add_argument("--esp-port", default=self.ESP_PORT, type=int, dest="ESP_PORT",
                                  help="ESP device port")
        optionParser.add_argument("--esp-listen-ip", default=self.ESP_LISTEN_IP, type=str, dest="ESP_LISTEN_IP",
                                  help="ESP server address")
        optionParser.add_argument("--esp-listen-port", default=self.ESP_LISTEN_PORT, type=int, dest="ESP_LISTEN_PORT",
                                  help="ESP server port")
        optionParser.add_argument("--esp-buffer", default=self.ESP_BUFFER, type=int, dest="ESP_BUFFER",
                                  help="ESP server socket buffer")
        optionParser.add_argument("--esp-precision", default=self.ESP_PRECISION, type=float, dest="ESP_PRECISION",
                                  help="ESP timing precision [s]")
        optionParser.add_argument("--esp-ack-timeout", default=self.ESP_ACK_TIMEOUT, type=float, dest="ESP_ACK_TIMEOUT",
                                  help="ESP ACK timeout (UDP) [s]")
        optionParser.add_argument("--esp-poll-interval", default=self.ESP_POLL_INTERVAL, type=float, dest="ESP_POLL_INTERVAL",
                                  help="ESP device poll interval [s]")
        optionParser.add_argument("--esp-poll-cmd", default=self.ESP_POLL_CMD, type=str, dest="ESP_POLL_CMD",
                                  help="ESP device poll command")
        optionParser.add_argument("--esp-force-ack-debug", default=self.ESP_FORCE_ACK_DEBUG, dest="ESP_FORCE_ACK_DEBUG",
                                  help="ESP force ACK debug", action="store_true")
        optionParser.add_argument("--esp-poll-nl", default=self.ESP_POLL_NL, type=int, dest="ESP_POLL_NL",
                                  help="ESP poll messages (.:) length")

        user_options = optionParser.parse_args()
        for p, v in vars(user_options).iteritems():
            if p in self.param:
                self.param[p] = v

    def __repr__(self):
        return "<" + type(self).__name__ + "> " + pprint.pformat(vars(self), indent=4, width=1)

    def __getattr__(self, name):
        if name in self.const:
            return self.const[name]
        elif name in self.param:
            return self.param[name]
        return None

    def setParam(self, name, value):
        self.param[name] = value

    def code2mode(self, code):
        return self.code_to_mode[code]

    def mode2code(self, mode):
        return self.mode_to_code[mode]

    def setIpNetwork(self, ipNetwork):
        self.ipNetwork = ipNetwork

    def string2bool(self, text):
        return str(text).lower() in ['true', '1', 't', 'y', 'yes']


class EspSender(threading.Thread):

    def __init__(self, device, conf):
        super(EspSender, self).__init__()
        self.daemon = True

        self.conf = conf

        self.debugAck = self.conf.ESP_FORCE_ACK_DEBUG

        self.out_queue = Queue.Queue()
        self.signal_queue = Queue.Queue()

        self.device = device
        self.ip = str(self.conf.ipNetwork[device])

        self.last_send = -1

        self.pin_values = {}

        print "#" + str(device) + " UDP to " + str(self.ip)

    def updateSignalState(self):
        try:
            # signal, signal_ts
            signal_record = self.signal_queue.get_nowait()
            data = signal_record["signal"]
            if self.debugAck:
                print "#"+str(self.device)+" ACK:"+str(int((signal_record["signal_ts"]-self.last_send)*1000))+" "+data
            else:
                sys.stdout.write(':')
            self.last_send = -1
            for value_pair in data.split(";"):
                pin_value = value_pair.split(" ")
                if len(pin_value) == 2:
                    pin, value = pin_value
                    if str(pin) == "name":
                        pass
                    elif len(pin) > 0:
                        self.pin_values[pin] = value

        except Queue.Empty:
            # sys.stdout.write(":")
            # sys.stdout.flush()
            pass
        if (time.time() - self.last_send) > self.conf.ESP_ACK_TIMEOUT:
            # print "  #"+str(self.device)+" Timeout"
            self.last_send = -1

    def run(self):
        commands = ""
        cmd_count = 0
        elder_cmd_ts = 0
        force_send = True
        last_poll = 0
        poll_nl = self.conf.ESP_POLL_NL

        while True:

            try:
                out_record = self.out_queue.get(True, self.conf.ESP_PRECISION)

                cmd = out_record["cmd"]
                cmd_ts = out_record["cmd_ts"]
                force_send = out_record["exec_wait"]

                cmd_count += 1

                if len(commands) > 0 and not commands.endswith("\n"):
                    commands = commands + "\n"
                commands = commands + cmd

                if elder_cmd_ts == 0:
                    elder_cmd_ts = cmd_ts

            except Queue.Empty:
                # sys.stdout.write(":")
                # sys.stdout.flush()
                pass

            self.updateSignalState()

            time_now = time.time()
            if time_now-last_poll > self.conf.ESP_POLL_INTERVAL and len(commands) == 0:
                if len(commands) > 0 and not commands.endswith("\n"):
                    commands = commands + "\n"
                commands = commands + self.conf.ESP_POLL_CMD

            if len(commands) > 0:
                if force_send and self.last_send < 0:
                    if commands == self.conf.ESP_POLL_CMD:
                        sys.stdout.write('.')
                        poll_nl -= 1
                        if poll_nl < 0:
                            print
                            poll_nl = self.conf.ESP_POLL_NL
                    else:
                        print("#" + str(self.device) + "   force=" + str(force_send) + " count=" + str(cmd_count) +
                              " delay=" + str(int((time_now-elder_cmd_ts)*1000)) + " now=" + str(time_now) +
                              " elder=" + str(elder_cmd_ts) + " last=" + str(self.last_send))
                        self.debugAck = True
                        poll_nl = self.conf.ESP_POLL_NL

                    self.send2esp(commands)

                    commands = ""
                    cmd_count = 0
                    elder_cmd_ts = 0
                    force_send = True
                    last_poll = time.time()
                    self.debugAck = self.conf.ESP_FORCE_ACK_DEBUG

    def buildSignal(self, signal, signal_ts):
        return {"signal": signal, "signal_ts": signal_ts}

    def putSignal(self, signal, signal_ts):
        self.signal_queue.put(self.buildSignal(signal, signal_ts))

    def buildOut(self, cmd, cmd_ts, exec_wait):
        return {"cmd": cmd, "cmd_ts": cmd_ts, "exec_wait": exec_wait}

    def putOut(self, cmd, cmd_ts, exec_wait):
        self.out_queue.put(self.buildOut(cmd, cmd_ts, exec_wait))

    def send2esp(self, command):
        self.conf.espNetHandler.send2esp(self.device, self.ip, command)

        self.last_send = time.time()

    def getIp(self):
        return self.ip

    def getOutQueue(self):
        return self.out_queue

    def getSignalQueue(self):
        return self.signal_queue

    def getPinValues(self):
        return self.pin_values

    def closeEsp(self):
        self.conf.espNetHandler.closeEsp()


class EspHandler(threading.Thread):

    def __init__(self, device, conf):
        super(EspHandler, self).__init__()
        self.daemon = True

        self.conf = conf

        self.sender = None

        self.device = None
        self.in_queue = None
        self.pin_last_command = {}

        if (device > 0) and (self.conf.ipNetwork is not None) and (device < self.conf.ipNetwork.size):
            self.device = device

            self.sender = EspSender(device, self.conf)
            self.sender.start()

            self.in_queue = Queue.Queue()
            print "#" + str(device) + " Handler to " + str(self.getIp())
        else:
            print "#" + str(device) + " Invalid device or net: " + str(self.conf.ipNetwork)

    def buildIn(self, command, pins, exec_wait):
        return {"command": command, "pins": pins, "exec_wait": exec_wait}

    def putIn(self, command, pins, exec_wait):
        self.in_queue.put(self.buildIn(command, pins, exec_wait))

    def getDeviceId(self):
        return self.device

    def getInQueue(self):
        return self.in_queue

    def ackReceived(self, data):
        self.sender.putSignal(data, time.time())

    def run(self):
        while True:
            # sys.stdout.write(".")
            # sys.stdout.flush()
            # command, pins, exec_wait
            in_record = self.in_queue.get()

            self.sendIfIn(in_record["command"], in_record["pins"], in_record["exec_wait"])

    def sendIfIn(self, command, pins, exec_wait):
        force_send = False

        if command == "reset_all":
            for p in self.pin_last_command:
                self.pin_last_command[p] = None
            force_send = True

        for p in pins:
            if p not in self.pin_last_command:
                self.pin_last_command[p] = None

            if command != self.pin_last_command[p]:
                force_send = True

            self.pin_last_command[p] = command

        if force_send:
            self.send2esp(command, exec_wait)

    def getIp(self):
        return self.sender.getIp()

    def send2esp(self, command, exec_wait):
        # print "#Out "+command
        self.sender.putOut(command, time.time(), exec_wait)

    def getPinValues(self):
        return self.sender.pin_values

    def bye(self):
        self.closeEsp()

    def closeEsp(self):
        self.sender.closeEsp()


# This class will handles any incoming request from Scratch


def makeScratchHandler(conf):

    class ScratchHandler(BaseHTTPRequestHandler):

        def __init__(self, *args):
            self.setConf(conf)
            BaseHTTPRequestHandler.__init__(self, *args)

        def setConf(self, conf):
            self.conf = conf

        def poll(self):
            response = ""

            for device_id, device in self.conf.espHandlersByDevice.iteritems():
                for pin, value in device.getPinValues().iteritems():
                    if len(response) > 0:
                        response += "\n"
                    digit = "false"
                    if self.conf.string2bool(value):
                        digit = "true"
                    response += "digitalRead/" + str(device_id) + "/" + str(pin) + " " + digit + "\n"
                    response += "analogRead/" + str(device_id) + "/" + str(pin) + " " + str(value) + "\n"
                    if device_id in self.conf.id2name:
                        name = self.conf.id2name[device_id]
                        response += "digitalRead/" + str(name) + "/" + str(pin) + " " + digit + "\n"
                        response += "analogRead/" + str(name) + "/" + str(pin) + " " + str(value) + "\n"

            return response

        def getFirmataPinMode(self, mode):
            return self.conf.mode2code(mode)

        def pinMode(self, device, pin, mode, exec_wait):
            command = "pinMode " + str(pin) + " " + str(mode)
            device.putIn(command, [pin], exec_wait)
            return self.conf.RESPONSE_OK

        def digitalWrite(self, device, pin, mode, exec_wait):
            command = "digitalWrite " + str(pin) + " " + str(mode)
            device.putIn(command, [pin], exec_wait)
            return self.conf.RESPONSE_OK

        def analogWrite(self, device, pin, value, exec_wait):
            command = "analogWrite " + str(pin) + " " + str(value)
            device.putIn(command, [pin], exec_wait)
            return self.conf.RESPONSE_OK

        def analogPairWrite(self, device, pin1, pin2, value, exec_wait):
            command = "analogPairWrite " + str(pin1) + " " + str(pin2) + " " + str(value)
            device.putIn(command, [pin1, pin2], exec_wait)
            return self.conf.RESPONSE_OK

        def servoWrite(self, device, pin, value, exec_wait):
            command = "servoWrite " + str(pin) + " " + str(value)
            device.putIn(command, [pin], exec_wait)
            return self.conf.RESPONSE_OK

        def reset_all(self):
            command = "reset_all"
            for device_id in self.conf.espHandlersByDevice:
                self.conf.espHandlersByDevice[device_id].putIn(command, [], True)
            return self.conf.RESPONSE_OK

        def initNet(self, net, maskBits):
            self.conf.setIpNetwork(IPNetwork(net + "/" + maskBits))
            print "IP net: " + str(self.conf.ipNetwork)
            conf.espNetHandler.send2esp("BROADCAST", str(self.conf.ipNetwork.broadcast), "getName")
            return self.conf.RESPONSE_OK

        def getOrCreateDevice(self, device_id):
            if device_id in self.conf.espHandlersByDevice:
                return self.conf.espHandlersByDevice[device_id]

            device = EspHandler(device_id, self.conf)
            if device.getInQueue() is not None:
                self.conf.espHandlersByDevice[device_id] = device
                self.conf.espHandlersByIp[device.getIp()] = device
                device.start()
                return device

            return None

        # Disable HTTP logging
        def log_message(self, form, *args):
            return

        # Handler for the GET requests
        def do_GET(self):
            resp_code = 200

            if self.path != "/poll":
                time_now = int(time.time() * 1000)
                # if lastCmdTs > -1:
                #     print "<> "+ str(time_now - lastCmdTs) +" "+ str(self.path)
                self.conf.lastCmdTs = time_now

            try:
                command = self.path.split("/")
                cmd = command[1]

                if cmd == "reset_all":
                    resp_body = self.reset_all()
                elif cmd == "initNet":
                    resp_body = self.initNet(command[2], command[3])
                elif cmd == "poll":
                    resp_body = self.poll()
                elif len(command) > 2:
                    print pprint.pformat(command)
                    exec_wait = command[2].lower().startswith("e")
                    pin = int(command[4])
                    device_name = command[3]
                    if device_name in self.conf.name2id:
                        device_id = self.conf.name2id[device_name]
                    else:
                        device_id = int(device_name)
                    device = self.getOrCreateDevice(device_id)
                    if device is None:
                        print "#" + command[3] + " UNKNOWN"
                        resp_body = "Unknown device"
                    else:
                        # print "cmd="+cmd
                        if cmd == "pinOutput":
                            resp_body = self.pinMode(
                                device, pin, self.conf.OUTPUT, exec_wait)
                        elif cmd == "pinInput":
                            resp_body = self.pinMode(device, pin, self.conf.INPUT, exec_wait)
                        elif cmd == "pinHigh":
                            resp_body = self.digitalWrite(
                                device, pin, self.conf.HIGH, exec_wait)
                        elif cmd == "pinLow":
                            resp_body = self.digitalWrite(
                                device, pin, self.conf.LOW, exec_wait)
                        elif cmd == "pinMode":
                            resp_body = self.pinMode(
                                device, pin, self.getFirmataPinMode(command[5]), exec_wait)
                        elif cmd == "digitalWrite":
                            if "high" == command[5].lower():
                                resp_body = self.digitalWrite(
                                    device, pin, self.conf.HIGH, exec_wait)
                            else:
                                resp_body = self.digitalWrite(
                                    device, pin, self.conf.LOW, exec_wait)
                        elif cmd == "analogWrite":
                            resp_body = self.analogWrite(
                                device, pin, int(command[5]), exec_wait)
                        elif cmd == "analogPairWrite":
                            resp_body = self.analogPairWrite(device, pin, int(
                                command[5]), int(command[6]), exec_wait)
                        elif cmd == "servoWrite":
                            resp_body = self.servoWrite(
                                device, pin, int(command[5]), exec_wait)
                        else:
                            resp_code = 400
                            resp_body = "unknown command: " + str(command)
                else:
                    resp_code = 400
                    resp_body = "unknown command: " + str(command)

            except ZeroDivisionError as e:
                resp_code = 400
                resp_body = "exception: " + str(e)
                pprint.pprint(e)

            self.send_response(resp_code)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            # Send the html message
            self.wfile.write(resp_body)
            return

    return ScratchHandler


class EspNetHandler(threading.Thread):

    def __init__(self, conf):
        super(EspNetHandler, self).__init__()
        self.daemon = True

        self.conf = conf
        self.debugAck = self.conf.ESP_FORCE_ACK_DEBUG

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((conf.ESP_LISTEN_IP, self.conf.ESP_LISTEN_PORT))
        print("Listening ESP on " + self.conf.ESP_LISTEN_IP + ":" +
              str(conf.ESP_LISTEN_PORT) + ", sending to :" + str(conf.ESP_PORT))

    def run(self):
        while True:
            data, addr = self.sock.recvfrom(self.conf.ESP_BUFFER)
            ip, port = addr
            name = ""
            s = self.conf.name_value_re.search(data)
            if s and self.conf.ipNetwork is not None:
                name = s.group(1)
                addr = IPAddress(ip)
                dev_id = addr.value - self.conf.ipNetwork.network.value
                self.conf.name2id[name] = dev_id
                self.conf.id2name[dev_id] = name
                print "ESP name: #" + str(self.conf.name2id[name]) + " " + str(ip) + ":" + str(port) + " = " + name

            if ip in self.conf.espHandlersByIp:
                if self.debugAck:
                    print "#" + str(self.conf.espHandlersByIp[ip].getDeviceId()) + " < " + data
                self.conf.espHandlersByIp[ip].ackReceived(data)
            else:
                if len(name) == 0:
                    print "Unknown ESP: " + str(ip) + ":" + str(port)

            self.debugAck = self.conf.ESP_FORCE_ACK_DEBUG

    def send2esp(self, device, ip, command):
        if command == self.conf.ESP_POLL_CMD:
            # sys.stdout.write(':')
            pass
        else:
            print "#" + str(device) + " > " + repr(command)
            self.debugAck = True

        if self.sock is not None:
            self.sock.sendto(command + "\n", (ip, self.conf.ESP_PORT))

    def closeEsp(self):
        self.sock.close()
        self.sock = None


def main():
    conf = EspConfig()

    try:
        # Create a web server and define the handler to manage the
        # incoming request
        server = HTTPServer((conf.SCRATCH_IP, conf.SCRATCH_PORT), makeScratchHandler(conf))
        print "Listening httpserver on " + str(conf.SCRATCH_IP) + ":" + str(conf.SCRATCH_PORT)

        conf.espNetHandler = EspNetHandler(conf)
        conf.espNetHandler.start()
        # Wait forever for incoming htto requests
        server.serve_forever()

    except KeyboardInterrupt:
        print "\n^C received, shutting down the web server"
        if server is not None:
            server.socket.close()
        for device in conf.espHandlersByDevice.itervalues():
            device.closeEsp()


if __name__ == "__main__":
    main()

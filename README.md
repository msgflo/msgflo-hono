Eclipse Hono connector for MsgFlo
=================================

This tool discovers devices on an [Eclipse Hono](http://www.eclipse.org/hono/) service and makes them participants in a [MsgFlo](https://msgflo.org/) network.

With MsgFlo you can easily connect any Hono-enabled sensors to any arbitrary data processing functionality, be it a [NoFlo](https://noflojs.org) graph, a Rust or Python program, or a MsgFlo-connected IoT actuator.

For example, here is a [Bosch XDK](https://xdk.bosch-connectivity.com/) talking to a NoFlo graph, with [Flowhub IDE](https://flowhub.io) showing the live data flowing through:

![XDK in MsgFlo](http://i.imgur.com/fVybIlq.png)

## Installation

You need access to a Hono installation, and a MsgFlo-compatible message queue. You also need Node.js. Install the Hono MsgFlo connector with:

```bash
$ npm install -g msgflo-hono
```

## Running

The msgflo-hono tool accepts the following arguments:

* `hono`: URL (including authentication) to a Hono instance
* `msgflo`: MsgFlo message broker URL
* `tenant`: Hono tenant identifier
* `filter`: (optional) filter for device identifiers to expose

Example:

```bash
$ ./bin/msgflo-hono --hono amqp://username:password@hono.bosch-iot-suite.com:15672 --msgflo mqtt://localhost --tenant bcx --filter xdk
```

## Working principle

What this tool does is:

* Subscribe to Hono telemetry information
* Collect telemetry and produce device information based on the telemetry data
* Register discovered devices as [MsgFlo foreign participants](https://msgflo.org/docs/foreign/)
* Forward telemetry from Hono to the MsgFlo network

# fairyNode

Framework for ESP8266 on top of [nodemcu](https://github.com/nodemcu/nodemcu-firmware/) firmware

## Requirements
* [LFS](https://nodemcu.readthedocs.io/en/master/lfs/) 
* nodemcu modules: sjson,net,wifi,mqtt and more

## Features
* Modular design - framework allows to select which files are needed for specific project and should be compiled into lfs blob
* OTA through simple rest api - LFS, files on spiffs and configuration can be updated through wi-fi. It is enough to setup a server
* TODO

## Modules
* TODO

### Services
* mqtt
* sensor
* cmd
* ntp
* gpio
* TODO

### Supported sensors
* pcf8591 - partial support, dac is not exposed
* ds18b20
* dht11
* TODO

## Configuration
* TODO

## Limtations
* Some
* TODO

## Capability with homie specification
Currently fairyNode should be compatible with 3.0.0 homie specification. However it is only tested with OpenHab. There are few non standard extensions uses.

### Non standard homie extensions
* `homie/device_id/$cmd` and `homie/device_id/$cmd/output` this topics are used to send commands to device and receive response. Only if command module is compiled into lfs.
* `homie/device_id/$stats` is replaced with node devinfo
* Almost no configuration is exposed as homie nodes

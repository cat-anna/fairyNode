# fairyNode

Framework for ESP8266 on top of [nodemcu](https://github.com/nodemcu/nodemcu-firmware/) firmware

## Requirements
* [LFS](https://nodemcu.readthedocs.io/en/master/lfs/) 
* nodemcu modules: sjson,net,wifi,mqtt,

## Features
* Modular design - framework allows to select which files are needed for specific project and should be compiled into lfs blob
* OTA through simple rest api - LFS blob can be updated through wifi. It is enough to setup a server
* TODO

## Modules
* Command - allows to send simple commands to the device and get response. List of available commands depends on compiled in files. Commands are useful mostly for debug purposes.
* PCM - simple module that streams music from rest server and plays it using nodemcu pcm module. Playing from flash is not yet supported. This module has high memory usage during playback so device may became unstable.
* Clock32x8 - This module displays date and time and whatever is configured on daisy chained 8x8 dot displays on max7219. 
* TODO

### Services
* mqtt
* sensor
* cmd
* ntp
* gpio
* irx - during implementation
* lcdpcf - hd44 over i2c - during implementation

### Supported sensors
* pcf8591 - partial support, dac is not exposed
* ds18b20
* dht11


## Configuration
* TODO

## Limtations
* UART can only be used as shell

## Capability with homie specification
Currently fairyNode should be compatible with 3.0.0 homie specification. However it is only tested with OpenHab. There are few non standard extensions uses.

### Non standard homie extensions
* `homie/device_id/$cmd` and `homie/device_id/$cmd/output` this topics are used to send commands to device and receive response. Only if command module is compiled into lfs.
* `homie/device_id/$stats` is replaced with node devinfo
* Almost no configuration is exposed as homie nodes

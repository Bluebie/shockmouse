# build with `coffee -wcmb .`
_ = require './node_modules/ds4/node_modules/lodash'
hid = require './node_modules/ds4/node_modules/node-hid'
ds4 = require './node_modules/ds4'
child_process = require 'child_process'
events = require('events')

# hid device filters
isDS4HID = (descriptor)-> (descriptor.vendorId == 1356 && descriptor.productId == 1476)
isBluetoothHID = (descriptor)-> descriptor.path.match(/^Bluetooth/)
isUSBHID = (descriptor)-> descriptor.path.match(/^USB/)

#parseDS4HIDData = ds4.parseDS4HIDData
console.log "started"
devices = hid.devices()
console.log "devices: " + devices
controller = _(devices).filter(isDS4HID).first()
console.log "got controller" if controller

throw new Error('Could not find desired controller.') unless controller

hidDevice = new hid.HID(controller.path)
console.log "got hid device for controlle"
offset = 0

if (isBluetoothHID(controller))
  offset = 2
  hidDevice.getFeatureReport(0x04, 66)

console.log "Spawning mousing servant (cliclick)"
# spawn cliclick
cliclick = child_process.spawn("#{__dirname}/bin/cliclick", ['-f', '-']);

console.log "Beginning parsing stream"
touches = []
previous_data = {}
hidDevice.on 'data', (buf)->
  #console.log(ds4.parseDS4HIDData(buf.slice(offset)))
  data = ds4.parseDS4HIDData(buf.slice(offset))
  touches = []
  makeTouchObj = (info, idx)-> {x: info["trackPadTouch#{idx}X"], y: info["trackPadTouch#{idx}Y"], active: info["trackPadTouch#{idx}Active"], id: info["trackPadTouch#{idx}Id"]}
  fire = (name, data)-> console.log "#{name}:", data
  
  for idx in [0,1]
    old_touch = makeTouchObj(previous_data, idx)
    touch = makeTouchObj(data, idx)
    fire('touchstart', touch) if old_touch.id != touch.id and touch.active
    fire('touchend', touch) if old_touch.active and !touch.active
    fire('touchmove', touch) if (old_touch.x != touch.x or old_touch.y != old_touch.y) and old_touch.active and touch.active
      
  
  previous_data = data
  #console.log
  #  x: data.trackPadTouch0X
  #  y: data.trackPadTouch0Y
  
class Controller extends events.EventEmitter
  contructor: (device_descriptor)->
    @hid = new hid.HID(device_descriptor.path)
    console.log "got hid device for controlle"
    @wireless = isBluetoothHID(device_descriptor)
    @hid.getFeatureReport(0x04, 66) if @wireless # enable touch pad, motion, etc...
    
    # setup some initial variables
    @report = {}
    @timestamp = new Date
    
    # parse incomming reports from controller
    @hid.on 'data', (buf)=>
      data = ds4.parseDS4HIDData(buf.slice(@wireless ? 2 : 0))
      #console.log data
      @_update data
  
  _update: (data)->
    @timestamp = new Date
    @report = data
    
    
exports.Controller = Controller
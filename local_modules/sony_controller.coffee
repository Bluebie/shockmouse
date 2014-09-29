# build with `coffee -wcmb .`
_ = require '../node_modules/ds4/node_modules/lodash'
hid = require '../node_modules/ds4/node_modules/node-hid'
ds4 = require '../node_modules/ds4'
events = require('events')

# hid device filters
isDS4HID = (descriptor)-> (descriptor.vendorId == 1356 && descriptor.productId == 1476)
isBluetoothHID = (descriptor)-> descriptor.path.match(/^Bluetooth/)
isUSBHID = (descriptor)-> descriptor.path.match(/^USB/)

# Represents a Sony DualShock 4 Gamepad
# Touchpad has resolution of 1920x940 and a maximum of two-point multitouch
# triggers are both analog and digital, and digitally read activated whenever analog value is > 0
# triggers and joysticks are 8-bit
# speaker (not yet implemented)
# RGB LED lamp on top (not yet implemented)
# Motion Sensors - accelerometer and gyro
# Accessory port (not yet implemented)
#
# Raw Report Sample:
# { leftAnalogX: 126,
#   leftAnalogY: 127,
#   rightAnalogX: 125,
#   rightAnalogY: 130,
#   l2Analog: 0,
#   r2Analog: 0,
#   dPadUp: false,
#   dPadRight: false,
#   dPadDown: false,
#   dPadLeft: false,
#   x: false,
#   cricle: false,
#   square: false,
#   triangle: false,
#   l1: false,
#   l2: false,
#   r1: false,
#   r2: false,
#   l3: false,
#   r3: false,
#   share: false,
#   options: false,
#   trackPadButton: false,
#   psButton: false,
#   motionY: 1,
#   motionX: 4,
#   motionZ: 7,
#   orientationRoll: -329,
#   orientationYaw: 7651,
#   orientationPitch: 3405,
#   trackPadTouch0Id: 36,
#   trackPadTouch0Active: false,
#   trackPadTouch0X: 160,
#   trackPadTouch0Y: 160,
#   trackPadTouch1Id: 6,
#   trackPadTouch1Active: false,
#   trackPadTouch1X: 1557,
#   trackPadTouch1Y: 809,
#   timestamp: 48,
#   batteryLevel: 2 }

class DS4TouchEvent extends events.EventEmitter
  constructor: ->
    @created = new Date
    @delta = {x: 0, y: 0}

tickEmit = (target, event, arg)->
  return -> target.emit(event, arg)

class DS4Gamepad extends events.EventEmitter
  constructor: (device_descriptor)->
    @hid = new hid.HID(device_descriptor.path)
    console.log "got hid device for controlle"
    @wireless = !!isBluetoothHID(device_descriptor)
    @hid.getFeatureReport(0x04, 66) if @wireless # enable touch pad, motion, etc...
    
    # setup some initial variables
    @report = {}
    @timestamp = new Date
    @trackpad = { touches: [] }
    @_previous_report = {}
    @_touch_obj_cache = [] # cache touch objects so users can add metadata to them which survives between events
    @_config = {red: 0.25, green: 0.25, blue: 0.25, small_rumble: 0, big_rumble: 0, flash_on_duration: 0.0, flash_off_duration: 0.0}
    
    # parse incomming reports from controller
    @hid.on 'data', (buf)=>
      data = ds4.parseDS4HIDData(buf.slice(if @wireless then 2 else 0))
      #console.log data
      @_receive_report data
  
  
  # optionally accepts: {
  #   red:0.0-1.0, green:0.0-1.0, blue:0.0-1.0,
  #   small_rumble: 0.0-1.0, big_rumble: 0.0-1.0
  #   flashing: boolean, flash_on_duration: 0.0-2.5 (seconds), flash_off_duration: 0.0-2.5 (seconds)
  set: (changes)->
    @_config[key] = value for key, value of changes

    if @wireless
      pkt = new Array(77)
      pkt[0] = 0x11 # feature report id
      pkt[1] = 128
      pkt[3] = 255
      offset = 3
    else
      pkt = new Array(31)
      pkt[0] = 0x05 # feature report id
      pkt[1] = 255
      offset = 1

    prep = (val)-> Math.max(0, Math.min(Math.round(val * 255), 255))

    # config data
    pkt[offset+3] = prep(@_config.small_rumble)
    pkt[offset+4] = prep(@_config.big_rumble)
    pkt[offset+5] = prep(@_config.red)
    pkt[offset+6] = prep(@_config.green)
    pkt[offset+7] = prep(@_config.blue)
    pkt[offset+8] = prep(@_config.flash_on_duration / 2.55)
    pkt[offset+9] = prep(@_config.flash_off_duration / 2.55)
    
    pkt[i] ?= 0 for i in [0...pkt.length] # replace any nulls with 0's
    @hid.write pkt
  
  _receive_report: (data)->
    #@timestamp = new Date
    @report = data
    
    # share report to interested listeners
    @emit 'report', data
    
    # detect changes on the touchpad
    @trackpad.touches = []
    makeTouchObj = (info, idx)->
      {
        x: info["trackPadTouch#{idx}X"]
        y: info["trackPadTouch#{idx}Y"]
        active: info["trackPadTouch#{idx}Active"]
        id: info["trackPadTouch#{idx}Id"]
      }
    
    for idx in [0,1]
      # update touch cache
      old_touch = makeTouchObj(@_previous_report, idx)
      new_touch = makeTouchObj(data, idx)
      @_touch_obj_cache[new_touch.id] ||= new DS4TouchEvent
      touch = @_touch_obj_cache[new_touch.id]
      touch[key] = value for key, value of new_touch # update touch object in cache
      touch.delta.x = new_touch.x - old_touch.x
      touch.delta.y = new_touch.y - old_touch.y
      
      if old_touch.id != new_touch.id and new_touch.active
        process.nextTick tickEmit(this, 'touchstart', touch)
      if old_touch.active and !new_touch.active
        @_touch_obj_cache[touch.id] = null
        process.nextTick tickEmit(this, 'touchend', touch)
        process.nextTick tickEmit(touch, 'touchend', touch)
      if (old_touch.x != new_touch.x or old_touch.y != new_touch.y) and old_touch.active and new_touch.active
        process.nextTick tickEmit(this, 'touchmove', touch)
        process.nextTick tickEmit(touch, 'touchmove', touch)
      @trackpad.touches.push(touch) if touch.active
    
    #@trackpad.touches.sort((a,b)-> a.id - b.id)
    
    # detect changes to buttons
    for key, value of @report
      if value == true and @_previous_report[key] == false
        process.nextTick tickEmit(this, 'keydown', key)
        process.nextTick tickEmit(this, "#{key}")
      if value == false and @_previous_report[key] == true
        process.nextTick tickEmit(this, 'keyup', key)
        process.nextTick tickEmit(this, "#{key}Release")
      if value != @_previous_report[key] and typeof(value) == 'number' and key != 'timestamp'
        process.nextTick tickEmit(this, 'change', key, value)
        process.nextTick tickEmit(this, "#{key}Change", value)
    
    @_previous_report = data
  

DS4Gamepad.devices =-> hid.devices().filter(isDS4HID)

exports.Gamepad = DS4Gamepad
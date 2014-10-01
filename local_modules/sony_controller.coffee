# build with `coffee -wcmb .`
_ = require '../node_modules/ds4/node_modules/lodash'
hid = require '../node_modules/ds4/node_modules/node-hid'
#ds4 = require '../node_modules/ds4'
Color = require 'color'
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
#   cross: false,
#   circle: false,
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
    @_config = {led: '#000005', blink: false, rumble: 0}
    
    # parse incomming reports from controller
    @hid.on 'data', (buf)=>
      data = @_parse_report_data(buf.slice(if @wireless then 2 else 0))
      #console.log data
      @_receive_report data
  
  
  # optionally accepts: {
  #   led: "any valid html color code"
  #   blink: false, true, or {on: 0-2.55, off: 0-2.55} to specify light flash duration
  #   rumble: 0-1, or {fine: 0-1, coarse: 0-1} to set individual values
  set: (changes)->
    throw new Error "Unknown setting #{setting}" for setting, value of changes when !@_config[setting]?
    @_config[key] = value for key, value of changes
    @_config.rumble_coarse = @_config.rumble_fine = changes.rumble if changes.rumble?
    
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
    
    color = Color(@_config.led)
    
    blinkmode = if typeof(@_config.blink) is 'object'
      @_config.blink
    else if @_config.blink is true
      { on: 0.25, off: 0.5 }
    else if @_config.blink is false
      {on: 0, off: 0}
    else
      throw new Error "Blink value invalid"
    
    rumble = if typeof(@_config.rumble) is 'object'
      @_config.rumble
    else
      {fine: @_config.rumble, coarse: @_config.rumble}
    
    throw new Error "Blink durations cannot exceed 2.55 seconds" if blinkmode.on > 2.55 or blinkmode.off > 2.55
    throw new Error "Rumble values must be numbers between 0.0 and 1.0" unless typeof(rumble.coarse) is 'number' and 0 <= rumble.coarse <= 1
    throw new Error "Rumble values must be numbers between 0.0 and 1.0" unless typeof(rumble.fine) is 'number' and 0 <= rumble.fine <= 1
    
    # config data
    pkt[offset+3] = prep(rumble.fine)
    pkt[offset+4] = prep(rumble.coarse)
    pkt[offset+5] = color.red()
    pkt[offset+6] = color.green()
    pkt[offset+7] = color.blue()
    pkt[offset+8] = prep(blinkmode.on / 2.55)
    pkt[offset+9] = prep(blinkmode.off / 2.55)
    
    pkt[i] ?= 0 for i in [0...pkt.length] # replace any nulls with 0's
    @hid.write pkt
  
  
  # Internal: Read new data from Wireless Controller packet, fire off events and stuff
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
    changes = {}
    for key, value of @report
      if value is true and @_previous_report[key] is false
        changes[key] = value
        process.nextTick tickEmit(this, 'keydown', key)
        process.nextTick tickEmit(this, "#{key}")
      if value is false and @_previous_report[key] is true
        changes[key] = value
        process.nextTick tickEmit(this, 'keyup', key)
        process.nextTick tickEmit(this, "#{key}Release")
      if key != 'timestamp' and typeof(value) isnt 'boolean' and JSON.stringify(value) isnt JSON.stringify(@_previous_report[key])
        changes[key] = value
        #process.nextTick tickEmit(this, 'change', key, value)
        process.nextTick tickEmit(this, "#{key}Change", value)
    @emit 'change', changes if (key for key of changes).length isnt 0
    @_previous_report = data
  
  _parse_report_data: (buf)->
    {
      leftAnalog: {x: buf[1] / 127.5 - 1, y: buf[2] / 127.5 - 1}
      rightAnalog: {x: buf[3] / 127.5 - 1, y: buf[4] / 127.5 - 1}
      l2Analog: buf[8] / 255
      r2Analog: buf[9] / 255

      dPadUp:    buf[5] is 0 || buf[5] is 1 || buf[5] is 7
      dPadRight: buf[5] is 1 || buf[5] is 2 || buf[5] is 3
      dPadDown:  buf[5] is 3 || buf[5] is 4 || buf[5] is 5
      dPadLeft:  buf[5] is 5 || buf[5] is 6 || buf[5] is 7

      cross: (buf[5] & 32) isnt 0
      circle: (buf[5] & 64) isnt 0
      square: (buf[5] & 16) isnt 0
      triangle: (buf[5] & 128) isnt 0

      l1: (buf[6] & 0x01) isnt 0
      l2: (buf[6] & 0x04) isnt 0
      r1: (buf[6] & 0x02) isnt 0
      r2: (buf[6] & 0x08) isnt 0
      l3: (buf[6] & 0x40) isnt 0
      r3: (buf[6] & 0x80) isnt 0

      share: (buf[6] & 0x10) isnt 0
      options: (buf[6] & 0x20) isnt 0
      trackPadButton: (buf[7] & 2) isnt 0
      psButton: (buf[7] & 1) isnt 0

      # ACCEL/GYRO
      motionY: buf.readInt16LE(13)
      motionX: -buf.readInt16LE(15)
      motionZ: -buf.readInt16LE(17)

      orientationRoll: -buf.readInt16LE(19)
      orientationYaw: buf.readInt16LE(21)
      orientationPitch: buf.readInt16LE(23)

      # TRACKPAD
      trackPadTouch0Id: buf[35] & 0x7f
      trackPadTouch0Active: (buf[35] >> 7) is 0
      trackPadTouch0X: ((buf[37] & 0x0f) << 8) | buf[36]
      trackPadTouch0Y: buf[38] << 4 | ((buf[37] & 0xf0) >> 4)

      trackPadTouch1Id: buf[39] & 0x7f
      trackPadTouch1Active: (buf[39] >> 7) is 0
      trackPadTouch1X: ((buf[41] & 0x0f) << 8) | buf[40]
      trackPadTouch1Y: buf[42] << 4 | ((buf[41] & 0xf0) >> 4)

      #timestamp: buf[7] >> 2
      batteryLevel: buf[12]
    }
  

DS4Gamepad.devices =-> hid.devices().filter(isDS4HID)

exports.Gamepad = DS4Gamepad
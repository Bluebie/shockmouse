# build with `coffee -wcmb .`
hid = require '../node_modules/ds4/node_modules/node-hid'
Color = require 'color'
events = require 'events'
{crc32} = require "crc"

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
class DS4Gamepad extends events.EventEmitter
  constructor: (device_descriptor)->
    @hid = new hid.HID(device_descriptor.path)
    @wireless = !!isBluetoothHID(device_descriptor)
    @hid.getFeatureReport(0x04, 66) if @wireless # enable touch pad, motion, etc...
    
    # setup some initial variables
    @report = {}
    @updated = Date.now
    @trackpad = { touches: [] }
    #@_previous_report = {}
    @_touch_obj_cache = [] # cache touch objects so users can add metadata to them which survives between events
    @deadzone = 0.075
    @zero_padding = 0 for a in [0..256]
    @ratelimit = false # set this to an fps integer number to throttle events (and improve CPU load a bit)
    @_config = {led: '#000005', blink: false, rumble: 0}
    @set({}) # update controller with defaults
    
    # parse incomming reports from controller
    @hid.on 'data', (buf)=>
      return if @ratelimit and (Date.now() - @updated) < (1000 / @ratelimit)
      @updated = Date.now()
      
      data = new DS4Report((if @wireless then buf.slice(2) else buf), this)
      @_receive_report data
  
  
  # optionally accepts: {
  #   led: "any valid html/css color code"
  #   blink: false, true, or {on: 0-2.55, off: 0-2.55} to specify light flash duration
  #   rumble: 0.0-1.0, or {fine: 0.0-1.0, coarse: 0.0-1.0} to set individual values
  # NOTE: Doesn't work over bluetooth yet. Works great over USB.
  set: (changes)->
    throw new Error "Unknown setting #{setting}" for setting, value of changes when !@_config[setting]?
    @_config[key] = value for key, value of changes
    @_config.rumble_coarse = @_config.rumble_fine = changes.rumble if changes.rumble?

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
    
    packet_data = [
      prep(rumble.fine), prep(rumble.coarse),
      color.red(), color.green(), color.blue(),
      prep(blinkmode.on / 2.55), prep(blinkmode.off / 2.55)
    ]

    # config data
    if @wireless
      # template packet from http://eleccelerator.com/wiki/index.php?title=DualShock_4#0x11_2
      packet = new Buffer([
        0xa2, 0x11, 0xc0, 0x20, 0xf0, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x43, 0x43, 0x00, 0x4d, 0x85, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd8, 0x8e, 0x94, 0xdd
      ])
      # paste in our packet data
      #packet.copy new Buffer(packet_data), 7 # add the message
      # update the crc32 bytes
      #packet.writeInt32LE(crc32.unsigned(packet[0...74]), 74)
      #console.log packet
      #@hid.sendFeatureReport packet.slice(1, 78)
    else
      @hid.write [0x5, 0xff, 0, 0].concat(packet_data)

  # Internal: Read new data from Wireless Controller packet, fire off events and stuff
  _receive_report: (data)->
    #@timestamp = new Date
    @report = data
    queue = [] # queue of events to dispatch once the new state is fully implemented
    @_previous_report ||= data # if this is the first time.. pretend no changes
    
    # detect changes on the touchpad
    touches = {
      active: []
      started: []
      moved: []
      ended: []
    }
    
    for touch_update, idx in data.trackpad
      
      touch = @_touch_obj_cache[touch_update.id] # fetch existing touch object
      @_touch_obj_cache[touch_update.id] = touch = new DS4TouchEvent unless touch # make new object if doesn't exist
      old_touch = @_previous_report.trackpad[idx]
      touch[key] = value for key, value of touch_update
      
      # generate position delta
      if old_touch.id is touch.id
        touch.delta.x = touch.x - old_touch.x
        touch.delta.y = touch.y - old_touch.y
        
      touches.active.push touch if touch.active
      
      if old_touch.id isnt touch.id and touch.active
        touches.started.push touch
      
      if old_touch.active and !touch.active
        touches.ended.push touch
        @_touch_obj_cache[touch.id] = null
      
      if (old_touch.x != touch.x or old_touch.y != touch.y) and old_touch.active and touch.active
        touches.moved.push touch
    
    # detect changes to buttons
    changes = {}
    for key, value of @report
      if value is true and @_previous_report[key] is false
        changes[key] = value
      if value is false and @_previous_report[key] is true
        changes[key] = value
      if key isnt 'timestamp' and key isnt 'trackpad' and typeof(value) isnt 'boolean' and JSON.stringify(value) isnt JSON.stringify(@_previous_report[key])
        changes[key] = value
    
    # share report to interested listeners
    @emit 'report', data
    @emit 'change', changes if (key for key of changes).length isnt 0
    for key, value of changes
      if value is true
        @emit 'keydown', key
        @emit key
      else if value is false
        @emit 'keyup', key
        @emit "#{key}Release"
      else
        @emit key, value
    
    @emit 'touch', touches if touches.started.length + touches.ended.length + touches.moved.length > 0
    @emit 'touchstart', touches.started if touches.started.length > 0
    touch.emit('move') for touch in touches.moved
    touch.emit('end') for touch in touches.ended
    @trackpad.touches = touches.active
    
    @_previous_report = data
    

# class representing a touch point - these objects are persistant, so if you receive a touchstart
# event from the DS4Gamepad, you can subscribe to move and end events on this object
class DS4TouchEvent extends events.EventEmitter
  constructor: ->
    @created = new Date
    @delta = {x: 0, y: 0}
  
  # some defaults in the prototype
  x: 0
  y: 0
  id: -1
  active: false
  
# class representing raw report data from Dualshock 4 device, optimised for performance on V8
# the gamepad class spends a lot of time creating these objects, so this is one of the most performance
# sensitive pieces of code. Be careful!
class DS4Report
  _deadzone_filter: (value)->
    if -@deadzone < value < @deadzone then 0 else value
    
  constructor: (buf, configuration)->
    @deadzone = configuration.deadzone
    @sensorsActive = configuration.wireless is false or (buf[0] is 0)
    @leftAnalog = {x: @_deadzone_filter(buf[1] / 127.5 - 1), y: @_deadzone_filter(buf[2] / 127.5 - 1)}
    @rightAnalog = {x: @_deadzone_filter(buf[3] / 127.5 - 1), y: @_deadzone_filter(buf[4] / 127.5 - 1)}
    @l2Analog = buf[8] / 255
    @r2Analog = buf[9] / 255
    
    dPad = buf[5] & 0b1111
    @up    = dPad is 0 || dPad is 1 || dPad is 7
    @down  = dPad is 3 || dPad is 4 || dPad is 5
    @left  = dPad is 5 || dPad is 6 || dPad is 7
    @right = dPad is 1 || dPad is 2 || dPad is 3
    
    @cross    = (buf[5] & 32) isnt 0
    @circle   = (buf[5] & 64) isnt 0
    @square   = (buf[5] & 16) isnt 0
    @triangle = (buf[5] & 128) isnt 0
    
    @l1 = (buf[6] & 0x01) isnt 0
    @l2 = (buf[6] & 0x04) isnt 0
    @r1 = (buf[6] & 0x02) isnt 0
    @r2 = (buf[6] & 0x08) isnt 0
    @l3 = (buf[6] & 0x40) isnt 0
    @r3 = (buf[6] & 0x80) isnt 0
    
    @share = (buf[6] & 0x10) isnt 0
    @options = (buf[6] & 0x20) isnt 0
    @trackpadButton = (buf[7] & 2) isnt 0
    @psButton = (buf[7] & 1) isnt 0
    
    if @sensorsActive
      # ACCEL/GYRO
      @motion =
        y: buf.readInt16LE(13)
        x: -buf.readInt16LE(15)
        z: -buf.readInt16LE(17)
      
      @orientation =
        roll: -buf.readInt16LE(19)
        yaw: buf.readInt16LE(21)
        pitch: buf.readInt16LE(23)
      
      
      # trackpad data
      # currently only looking at the first trackpad report package (usully there is only one)
      @trackpad = [
        {id: buf[35] & 0x7f, active: (buf[35] >> 7) is 0, x: ((buf[37] & 0x0f) << 8) | buf[36], y: buf[38] << 4 | ((buf[37] & 0xf0) >> 4)}
        {id: buf[39] & 0x7f, active: (buf[39] >> 7) is 0, x: ((buf[41] & 0x0f) << 8) | buf[40], y: buf[42] << 4 | ((buf[41] & 0xf0) >> 4)}
      ]

      @batteryLevel = buf[12] / 255
    else
      @motion = {x: 0, y: 0, z: 0}
      @orientation = {roll: 0, yaw: 0, pitch: 0}
      @trackpad = [{id: 0, active: false, x: 0, y: 0}, {id: 0, active: false, x: 0, y: 0}]
      @batteryLevel = -1.0

DS4Gamepad.devices =-> hid.devices().filter(isDS4HID)

exports.Gamepad = DS4Gamepad











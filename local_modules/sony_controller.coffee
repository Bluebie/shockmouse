# build with `coffee -wcmb .`
#_ = require '../node_modules/ds4/node_modules/lodash'
hid = require '../node_modules/ds4/node_modules/node-hid'
#ds4 = require '../node_modules/ds4'
Color = require 'color'
events = require('events')

# hid device filters
isDS4HID = (descriptor)-> (descriptor.vendorId == 1356 && descriptor.productId == 1476)
isBluetoothHID = (descriptor)-> descriptor.path.match(/^Bluetooth/)
isUSBHID = (descriptor)-> descriptor.path.match(/^USB/)

# crc32 = (array)->
#   crc = crc ^ (-1);
#   for(var i=0, iTop=str.length; i<iTop; i++) {
#       crc = ( crc >>> 8 ) ^ crc32.table[( crc ^ str.charCodeAt( i ) ) & 0xFF];
#   }
#   return (crc ^ (-1)) >>> 0;
# crc32.table_data = "00000000 77073096 EE0E612C 990951BA 076DC419 706AF48F E963A535 9E6495A3 0EDB8832 79DCB8A4 E0D5E91E 97D2D988 09B64C2B 7EB17CBD E7B82D07 90BF1D91 1DB71064 6AB020F2 F3B97148 84BE41DE 1ADAD47D 6DDDE4EB F4D4B551 83D385C7 136C9856 646BA8C0 FD62F97A 8A65C9EC 14015C4F 63066CD9 FA0F3D63 8D080DF5 3B6E20C8 4C69105E D56041E4 A2677172 3C03E4D1 4B04D447 D20D85FD A50AB56B 35B5A8FA 42B2986C DBBBC9D6 ACBCF940 32D86CE3 45DF5C75 DCD60DCF ABD13D59 26D930AC 51DE003A C8D75180 BFD06116 21B4F4B5 56B3C423 CFBA9599 B8BDA50F 2802B89E 5F058808 C60CD9B2 B10BE924 2F6F7C87 58684C11 C1611DAB B6662D3D 76DC4190 01DB7106 98D220BC EFD5102A 71B18589 06B6B51F 9FBFE4A5 E8B8D433 7807C9A2 0F00F934 9609A88E E10E9818 7F6A0DBB 086D3D2D 91646C97 E6635C01 6B6B51F4 1C6C6162 856530D8 F262004E 6C0695ED 1B01A57B 8208F4C1 F50FC457 65B0D9C6 12B7E950 8BBEB8EA FCB9887C 62DD1DDF 15DA2D49 8CD37CF3 FBD44C65 4DB26158 3AB551CE A3BC0074 D4BB30E2 4ADFA541 3DD895D7 A4D1C46D D3D6F4FB 4369E96A 346ED9FC AD678846 DA60B8D0 44042D73 33031DE5 AA0A4C5F DD0D7CC9 5005713C 270241AA BE0B1010 C90C2086 5768B525 206F85B3 B966D409 CE61E49F 5EDEF90E 29D9C998 B0D09822 C7D7A8B4 59B33D17 2EB40D81 B7BD5C3B C0BA6CAD EDB88320 9ABFB3B6 03B6E20C 74B1D29A EAD54739 9DD277AF 04DB2615 73DC1683 E3630B12 94643B84 0D6D6A3E 7A6A5AA8 E40ECF0B 9309FF9D 0A00AE27 7D079EB1 F00F9344 8708A3D2 1E01F268 6906C2FE F762575D 806567CB 196C3671 6E6B06E7 FED41B76 89D32BE0 10DA7A5A 67DD4ACC F9B9DF6F 8EBEEFF9 17B7BE43 60B08ED5 D6D6A3E8 A1D1937E 38D8C2C4 4FDFF252 D1BB67F1 A6BC5767 3FB506DD 48B2364B D80D2BDA AF0A1B4C 36034AF6 41047A60 DF60EFC3 A867DF55 316E8EEF 4669BE79 CB61B38C BC66831A 256FD2A0 5268E236 CC0C7795 BB0B4703 220216B9 5505262F C5BA3BBE B2BD0B28 2BB45A92 5CB36A04 C2D7FFA7 B5D0CF31 2CD99E8B 5BDEAE1D 9B64C2B0 EC63F226 756AA39C 026D930A 9C0906A9 EB0E363F 72076785 05005713 95BF4A82 E2B87A14 7BB12BAE 0CB61B38 92D28E9B E5D5BE0D 7CDCEFB7 0BDBDF21 86D3D2D4 F1D4E242 68DDB3F8 1FDA836E 81BE16CD F6B9265B 6FB077E1 18B74777 88085AE6 FF0F6A70 66063BCA 11010B5C 8F659EFF F862AE69 616BFFD3 166CCF45 A00AE278 D70DD2EE 4E048354 3903B3C2 A7672661 D06016F7 4969474D 3E6E77DB AED16A4A D9D65ADC 40DF0B66 37D83BF0 A9BCAE53 DEBB9EC5 47B2CF7F 30B5FFE9 BDBDF21C CABAC28A 53B39330 24B4A3A6 BAD03605 CDD70693 54DE5729 23D967BF B3667A2E C4614AB8 5D681B02 2A6F2B94 B40BBE37 C30C8EA1 5A05DF1B 2D02EF8D"
# crc32.table = parseInt(s,16) for s in crc32.table_data.split(' ')

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
      #@hid.sendFeatureReport [0x11, 128, 0, 0xff, 0, 0].concat(packet_data)
      #@hid.sendFeatureReport [0x11, 128, 0, 0xff, 0, 0].concat(packet_data, @zero_padding)[0...]
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
    
    #@counter: buf[7] >> 2
    #@timestamp: buf.readInt16LE(10) (is this type right?)
    @batteryLevel = buf[12] / 255

DS4Gamepad.devices =-> hid.devices().filter(isDS4HID)

exports.Gamepad = DS4Gamepad
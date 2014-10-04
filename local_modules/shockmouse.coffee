# # build with `coffee -wcmb .`
Gamepad = require('./local_modules/sony_controller').Gamepad
NextEvent = require './local_modules/next_event'

gamepads = Gamepad.devices()
console.log "gamepads:", gamepads
console.log "connecting to first..."

gamey = new Gamepad(gamepads[0])
console.log "connected!"
console.log "it is wireless?", gamey.wireless
natural_scrolling = NextEvent.defaults('com.apple.swipescrolldirection') is 1

gamey.set(led: 'blue')
gamey.ratelimit = 60
#gamey.set(blue: 0.5, red: 0.1, green: 0.1, flash_on_duration: 1, flash_off_duration: 1)
#setInterval((-> gamey.set(rumble: 1)), 1000)
mouse_gain =(x)-> # sigmoid function is similar to windows acceleration curve
  x * Math.abs(((1 / (1 + (Math.E ** (-x)))) - 0.5) * 2)


# tap click mode
tap_click_duration = 200 # milliseconds
gamey.on "touchstart", (touches)->
  #console.log "mouse move started", touch.id
  position = NextEvent.mouse() # get starting position (cached for move duration)
  touch.on 'touchmove', ->
    if gamey.trackpad.touches.length is 1
      # move mouse around with single touch
      position.x += mouse_gain(touch.delta.x)
      position.y += mouse_gain(touch.delta.y)
      position.x = 0 if position.x < 0
      position.y = 0 if position.y < 0
      NextEvent[if gamey.report.trackPadButton then 'mouse_drag' else 'mouse_move'](Math.round(position.x), Math.round(position.y))
    else
      # scroll with two finger touch
      NextEvent.mouse_scroll_wheel Math.round(mouse_gain(touch.delta.x)), Math.round(mouse_gain(if natural_scrolling then -touch.delta.y else touch.delta.y))
  touch.on 'touchend', ->
    #console.log "mouse movement complete", touch.id
    # tap click?
    if new Date - touch.created < tap_click_duration
      position = NextEvent.mouse()
      NextEvent.mouse_click(position.x, position.y, 'left')


# mouse button mechanism
button_down = null
gamey.on "trackpadButton", ->
  button_down = if gamey.trackpad.touches.length is 2 then 'right' else 'left'
  position = NextEvent.mouse()
  NextEvent.mouse_down(position.x, position.y, button_down)
gamey.on "trackpadButtonRelease", ->
  position = NextEvent.mouse()
  NextEvent.mouse_up(position.x, position.y, button_down)


# calculate equivilents to NeXT/Mac key repeat rates
key_repeat_interval = (1000 / 60) * (NextEvent.defaults('KeyRepeat') or 6)
key_repeat_initial_delay = (1000 / 60) * (NextEvent.defaults('InitialKeyRepeat') or 68) 

map_keyboard =(gamepad, keycode)->
  key_repeater = null
  gamey.on gamepad, ->
    NextEvent.key_down(keycode)
    clearInterval key_repeater
    key_repeater = setTimeout((->
      key_repeater = setInterval((->NextEvent.key_down(keycode)), key_repeat_interval)
    ), key_repeat_initial_delay)
  gamey.on "#{gamepad}Release", ->
    clearInterval key_repeater
    NextEvent.key_up(keycode)

map_keyboard 'up', 'UpArrow'
map_keyboard 'down', 'DownArrow'
map_keyboard 'left', 'LeftArrow'
map_keyboard 'right', 'RightArrow'
map_keyboard 'cross', 'Return'
map_keyboard 'circle', 'Escape'

svg = (x)->
  doc = document.getElementById('gamepad_graphic').getSVGDocument()
  doc.getElementById(x) if doc
# visualize button presses
gamey.on "keydown", (key)->
  element = svg("DS4_#{key}")
  element.style.fill = 'red' if element
gamey.on "keyup", (key)->
  element = svg("DS4_#{key}")
  element.style.fill = '' if element

# visualize analog sticks
for stick in ['leftAnalog', 'rightAnalog']
  gamey.on "change", (changes)->
    for property, value of changes
      if property.match /Analog/
        if element = svg("DS4_#{property}")
          element.transform.baseVal.getItem(0).setTranslate(value.x * 20, value.y * 20)

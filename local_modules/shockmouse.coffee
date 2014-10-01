# # build with `coffee -wcmb .`
Gamepad = require('./local_modules/sony_controller').Gamepad
NextEvent = require './local_modules/next_event'

gamepads = Gamepad.devices()
console.log "gamepads:", gamepads
console.log "connecting to first..."

gamey = new Gamepad(gamepads[0])
console.log "connected!"
console.log "it is wireless?", gamey.wireless
invert_scrolling = true

gamey.set(led: 'blue')
#gamey.set(blue: 0.5, red: 0.1, green: 0.1, flash_on_duration: 1, flash_off_duration: 1)
#setInterval((-> gamey.set(rumble: 1)), 1000)
mouse_gain =(x)-> # sigmoid function is similar to windows acceleration curve
  x * Math.abs(((1 / (1 + (Math.E ** (-x)))) - 0.5) * 2)

gamey.on "touchstart", (touch)->
  console.log "mouse move started", touch.id
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
      NextEvent.mouse_scroll_wheel Math.round(mouse_gain(touch.delta.x)), Math.round(mouse_gain(if invert_scrolling then -touch.delta.y else touch.delta.y))
  touch.on 'touchend', ->
    console.log "mouse movement complete", touch.id

# tap click mode
tap_click_duration = 200 # milliseconds
gamey.on 'touchend', (touch)->
  if new Date - touch.created < tap_click_duration
    position = NextEvent.mouse()
    NextEvent.mouse_click(position.x, position.y, 'left')

# mouse button mechanism
button_down = null
gamey.on "trackPadButton", ->
  button_down = if gamey.trackpad.touches.length is 1 then 'left' else 'right'
  position = NextEvent.mouse()
  NextEvent.mouse_down(position.x, position.y, button_down)
gamey.on "trackPadButtonRelease", ->
  position = NextEvent.mouse()
  NextEvent.mouse_up(position.x, position.y, button_down)

link_button =(gamepad, keycode)->
  gamey.on gamepad, ->
    console.log "#{gamepad} becomes #{keycode}"
    NextEvent.key_down(keycode)
  gamey.on "#{gamepad}Release", -> NextEvent.key_up(keycode)

link_button 'dPadUp', 'UpArrow'
link_button 'dPadDown', 'DownArrow'
link_button 'dPadLeft', 'LeftArrow'
link_button 'dPadRight', 'RightArrow'

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
        element = svg("DS4_#{property}")
        element.setAttribute('transform', "translate(#{value.x * 20},#{value.y*20})") if element

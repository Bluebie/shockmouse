# # build with `coffee -wcmb .`
Gamepad = require('./local_modules/sony_controller').Gamepad
NextEvent = require './local_modules/next_event'

gamepads = Gamepad.devices()
console.log "gamepads:", gamepads
console.log "connecting to first..."

gamey = new Gamepad(gamepads[0])
console.log "connected!"
console.log "it is wireless?", gamey.wireless

gamey.on "touchstart", (touch)->
  console.log "mouse move started", touch.id
  position = NextEvent.mouse() # get starting position
  touch.on 'touchmove', ->
    if gamey.trackpad.touches.length is 1
      # move mouse around with single touch
      position.x += touch.delta.x
      position.y += touch.delta.y
      position.x = 0 if position.x < 0
      position.y = 0 if position.y < 0
      NextEvent[if gamey.report.trackPadButton then 'mouse_drag' else 'mouse_move'](position.x, position.y)
    else
      # scroll with two finger touch
      NextEvent.mouse_scroll_wheel touch.delta.x, touch.delta.y
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

# visualize button presses
gamepad_graphic = document.getElementById('gamepad_graphic')
gamey.on "keydown", (key)->
  path = gamepad_graphic.contentDocument.getElementById("DS4_#{key}")
  path.style.fill = 'red' if path
gamey.on "keyup", (key)->
  path = gamepad_graphic.contentDocument.getElementById("DS4_#{key}")
  path.style.fill = '' if path

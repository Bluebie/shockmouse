# # build with `coffee -wcmb .`
# _ = require './node_modules/ds4/node_modules/lodash'
# hid = require './node_modules/ds4/node_modules/node-hid'
# ds4 = require './node_modules/ds4'
Gamepad = require('./controller').Gamepad
ChildProcess = require 'child_process'

gamepads = Gamepad.devices()
console.log "gamepads:", gamepads
console.log "connecting to first..."

gamey = new Gamepad(gamepads[0])
console.log "connected!"
console.log "it is wireless?", gamey.wireless
# gamey.on "touchmove", (touch)-> console.log "Touch moved!", touch
# gamey.on "keydown", (key)-> console.log "#{key} pressed!"
# gamey.on "change", (key, value)-> console.log "#{key} moved to #{value}"

#gamey.set(big_rumble: 1.0, red: 1, green: 0, blue: 0)

console.log "Spawning mousing servant (cliclick)"
# # spawn cliclick
cliclick = ChildProcess.spawn("#{__dirname}/bin/cliclick", ['-f', '-']);

#gamey.on "report", (report)-> console.log "report: ", report
mouse_delta = {x: 0, y: 0}
gamey.on "touchstart", (touch)->
  console.log "on ", touch.id
  touch.on 'touchmove', ->
    mouse_delta.x += touch.delta.x
    mouse_delta.y += touch.delta.y
  touch.on 'touchend', ->
    console.log "off", touch.id
gamey.on "trackPadButton", ->
  console.log "Button!"
  cliclick.stdin.write("c:+0,+0\n")
  
setInterval(->
  convert = (num)->
    num = Math.round(num / 2)
    if num < 0 then "#{num}" else "+#{num}"
  if mouse_delta.x != 0 or mouse_delta.y != 0
    cliclick.stdin.write("m:#{convert(mouse_delta.x)},#{convert(mouse_delta.y)}\n")
    mouse_delta = {x: 0, y: 0}
, 1000 / 30)
  
gamey.on "dPadUp", -> cliclick.stdin.write("kp:arrow-up\n")
gamey.on "dPadDown", -> cliclick.stdin.write("kp:arrow-down\n")
gamey.on "dPadLeft", -> cliclick.stdin.write("kp:arrow-left\n")
gamey.on "dPadRight", -> cliclick.stdin.write("kp:arrow-right\n")


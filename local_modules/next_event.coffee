# Module for posting HID events in to the NeXTSTEP system to move mouse around and enter keystrokes and things
ObjC = require '../node_modules/NodObjC'
ObjC.import 'ApplicationServices'
exports.objc = ObjC

# Do we need an Autorelease pool?
pool = ObjC.NSAutoreleasePool('alloc')('init')

post = (event)-> ObjC.CGEventPost ObjC.kCGHIDEventTap, event
create_mouse_event = ObjC.CGEventCreateMouseEvent
CGPointMake = ObjC.CGPointMake

# exports.display_size =->
#

# Fetch system settings, including details about keyboard and mouse
dict_proxy =(dict)->
  (key)->
    return dict unless key
    ret = dict('objectForKey', ObjC(key))
    ret = dict_proxy(ret) if ret and ret.getClassName?() == '__NSCFDictionary'
    return ret
update_defaults =(notification)->
  exports.defaults = dict_proxy(ObjC.NSUserDefaults('standardUserDefaults')('dictionaryRepresentation'))
  exports.defaults.update = update_defaults
# some interesting defaults:
#   com.apple.mouse.tapBehavior - tap to click touchpad behaviour - off = 0, on = 1
#   com.apple.swipescrolldirection - natural scrolling - off = 0, on = 1
#   com.apple.trackpad.enableSecondaryClick - right clicking
#   com.apple.trackpad.momentumScroll - 0 or 1
#   com.apple.trackpad.scrollBehavior - 2 seems to be required for two finger scrolling to work
#   com.apple.trackpad.twoFingerDoubleTapGesture - 0 or 1 (the dictionary lookup gesture)
#   com.apple.trackpad.twoFingerFromRightEdgeSwipeGesture - the notification center open gesture

  

# Subscribe to system setting changes
# notifier = ObjC.NSNotificationCenter('defaultCenter')
# notifier('addObserverForName',ObjC.NSUserDefaultsDidChangeNotification,
#                      'object',null,
#                       'queue',null,
#                  'usingBlock',ObjC(update_defaults, [ObjC.void, [ObjC.id]]))
update_defaults() # load initial defaults

# common details
hid_source = ObjC.CGEventSourceCreate(ObjC.kCGEventSourceStateHIDSystemState)

# mouse stuff:
mouse_buttons = ['left', 'right', 'center']
mouse_button_names = ['Left', 'Right']
mouse_button_name = (id)-> mouse_button_names[id] || 'Other'
exports.mouse_move = (x, y)->
  post create_mouse_event(hid_source, ObjC.kCGEventMouseMoved, CGPointMake(x, y), 0)

exports.mouse_down = (x, y, button = 'left', clicks = 1, clickid = null)->
  button = mouse_buttons.indexOf(button) if typeof(button) is 'string'
  event = create_mouse_event(hid_source, ObjC["kCGEvent#{mouse_button_name(button)}MouseDown"], CGPointMake(x, y), button)
  ObjC.CGEventSetIntegerValueField event, ObjC.kCGMouseEventClickState, clicks if clicks
  ObjC.CGEventSetIntegerValueField event, ObjC.kCGMouseEventNumber, clickid if clickid
  post event

exports.mouse_up = (x, y, button = 'left', clicks = 1, clickid = null)->
  button = mouse_buttons.indexOf(button) if typeof(button) is 'string'
  event = create_mouse_event(hid_source, ObjC["kCGEvent#{mouse_button_name(button)}MouseUp"], CGPointMake(x, y), button)
  ObjC.CGEventSetIntegerValueField event, ObjC.kCGMouseEventClickState, clicks if clicks
  ObjC.CGEventSetIntegerValueField event, ObjC.kCGMouseEventNumber, clickid if clickid
  post event

# this one seems pointless? implied by down and up I would expect!
exports.mouse_drag = (x, y, button = 'left')->
  button = mouse_buttons.indexOf(button) if typeof(button) is 'string'
  post create_mouse_event(hid_source, ObjC["kCGEvent#{mouse_button_name(button)}MouseDragged"], CGPointMake(x, y), button)

# emulate a fast single click
exports.mouse_click = (args...)->
  exports.mouse_down args...
  exports.mouse_up args...

# emulate scrolling a number of pixels
exports.mouse_scroll_wheel = (scroll_x, scroll_y)->
  # sending in two events because of compatibility weirdness - some apps seem to ignore two wheel inputs
  post ObjC.CGEventCreateScrollWheelEvent(hid_source, ObjC.kCGScrollEventUnitPixel, 1, scroll_y)
  # post ObjC.CGEventCreateScrollWheelEvent(null, ObjC.kCGScrollEventUnitPixel, 2, scroll_y, scroll_x)

# get mouse position
exports.mouse =->
  ObjC.CGEventGetLocation(ObjC.CGEventCreate(null))

# keyboard stuff:
keyboard_event_masks =
  CapsLock: ObjC.kCGEventFlagMaskAlphaShift
  Shift:    ObjC.kCGEventFlagMaskShift
  Control:  ObjC.kCGEventFlagMaskControl
  Option:   ObjC.kCGEventFlagMaskAlternate
  Command:  ObjC.kCGEventFlagMaskCommand
  Function: ObjC.kCGEventFlagMaskSecondaryFn
modifiers_down = []

key_event = (keycode, down, flags)->
  keycode = exports.keys[keycode] if typeof(keycode) is 'string'
  event = ObjC.CGEventCreateKeyboardEvent(null, keycode, down)
  for flag in flags
    ObjC.CGEventSetFlags(event, keyboard_event_masks[flag]) if keyboard_event_masks[flag]?
  post event

exports.key_down = (keycode)->
  modifiers_down.push keycode if keyboard_event_masks[keycode]? and modifiers_down.indexOf(keycode) is -1
  key_event(keycode, true, modifiers_down)
  # keycode = exports.keys[keycode] if typeof(keycode) is 'string'
  # post ObjC.CGEventCreateKeyboardEvent(null, keycode, true)

exports.key_up = (keycode)->
  modifiers_down = modifiers_down.filter (mod)-> mod isnt keycode
  key_event(keycode, false, modifiers_down)
  # keycode = exports.keys[keycode] if typeof(keycode) is 'string'
  # post ObjC.CGEventCreateKeyboardEvent(null, keycode, false)

exports.keystroke = (keys...)->
  for key in keys
    if typeof(key) is 'string' or typeof(key) is 'number'
      exports.key_down key
      exports.key_up key
    else if key.reverse? # array
      exports.key_down press for press in key
      exports.key_up press for press in key.reverse()

# Mac OS X Virtual Keycode table
exports.keys =   
  A                             : 0x00
  S                             : 0x01
  D                             : 0x02
  F                             : 0x03
  H                             : 0x04
  G                             : 0x05
  Z                             : 0x06
  X                             : 0x07
  C                             : 0x08
  V                             : 0x09
  B                             : 0x0B
  Q                             : 0x0C
  W                             : 0x0D
  E                             : 0x0E
  R                             : 0x0F
  Y                             : 0x10
  T                             : 0x11
  '1'                           : 0x12
  '2'                           : 0x13
  '3'                           : 0x14
  '4'                           : 0x15
  '6'                           : 0x16
  '5'                           : 0x17
  Equal                         : 0x18
  '9'                           : 0x19
  '7'                           : 0x1A
  Minus                         : 0x1B
  '8'                           : 0x1C
  '0'                           : 0x1D
  RightBracket                  : 0x1E
  O                             : 0x1F
  U                             : 0x20
  LeftBracket                   : 0x21
  I                             : 0x22
  P                             : 0x23
  L                             : 0x25
  J                             : 0x26
  Quote                         : 0x27
  K                             : 0x28
  Semicolon                     : 0x29
  Backslash                     : 0x2A
  Comma                         : 0x2B
  Slash                         : 0x2C
  N                             : 0x2D
  M                             : 0x2E
  Period                        : 0x2F
  Grave                         : 0x32
  KeypadDecimal                 : 0x41
  KeypadMultiply                : 0x43
  KeypadPlus                    : 0x45
  KeypadClear                   : 0x47
  KeypadDivide                  : 0x4B
  KeypadEnter                   : 0x4C
  KeypadMinus                   : 0x4E
  KeypadEquals                  : 0x51
  Keypad0                       : 0x52
  Keypad1                       : 0x53
  Keypad2                       : 0x54
  Keypad3                       : 0x55
  Keypad4                       : 0x56
  Keypad5                       : 0x57
  Keypad6                       : 0x58
  Keypad7                       : 0x59
  Keypad8                       : 0x5B
  Keypad9                       : 0x5C
  Return                        : 0x24
  Tab                           : 0x30
  Space                         : 0x31
  Delete                        : 0x33
  Escape                        : 0x35
  Command                       : 0x37
  Shift                         : 0x38
  CapsLock                      : 0x39
  Option                        : 0x3A
  Control                       : 0x3B
  RightShift                    : 0x3C
  RightOption                   : 0x3D
  RightControl                  : 0x3E
  Function                      : 0x3F
  F17                           : 0x40
  VolumeUp                      : 0x48
  VolumeDown                    : 0x49
  Mute                          : 0x4A
  F18                           : 0x4F
  F19                           : 0x50
  F20                           : 0x5A
  F5                            : 0x60
  F6                            : 0x61
  F7                            : 0x62
  F3                            : 0x63
  F8                            : 0x64
  F9                            : 0x65
  F11                           : 0x67
  F13                           : 0x69
  F16                           : 0x6A
  F14                           : 0x6B
  F10                           : 0x6D
  F12                           : 0x6F
  F15                           : 0x71
  Help                          : 0x72
  Home                          : 0x73
  PageUp                        : 0x74
  ForwardDelete                 : 0x75
  F4                            : 0x76
  End                           : 0x77
  F2                            : 0x78
  PageDown                      : 0x79
  F1                            : 0x7A
  LeftArrow                     : 0x7B
  RightArrow                    : 0x7C
  DownArrow                     : 0x7D
  UpArrow                       : 0x7E
  ISO_Section                   : 0x0A
  JIS_Yen                       : 0x5D
  JIS_Underscore                : 0x5E
  JIS_KeypadComma               : 0x5F
  JIS_Eisu                      : 0x66
  JIS_Kana                      : 0x68



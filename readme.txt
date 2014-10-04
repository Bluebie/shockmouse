Very early days here! Here be dragons! Pre-alpha experiments

To run this little experiment, first connect a Sony DualShock4 controller via
either USB or Bluetooth, then open this folder with node-webkit 0.8.6-osx-ia32.
The trackpad on the controller should now control your mouse, including tap to
click and press in button clicking, two finger vertical scrolling, and dragging
by pressing in the trackpad button.

Todo before first beta release:
 - Improve GUI to be pretty and black themed
 - Checkbox for inverted scrolling
 - Make new gamepad graphic, prerendered images, check redrawing is fast
 - Try to find a way to power down extra sensors over bluetooth when idle
 - Get LED control working over bluetooth, or indicate controller state with on screen popup

Ideas/Todo:
 - Squash memory leaks! (progress being made!!)
 - Right click via two finger tap
 - Right click via the options button?
 - Acceleration for mouse, scrolling from system settings? or local settings?
 - Visualize touches on trackpad in UI because it's cool
 - Figure out why horizontal scrolling doesn't work in NextEvent
<3 (COMPLETED) Retrieve and respect inverted scrolling system setting
<3 (COMPLETED) Key repeat for arrow buttons (menu navigation) from system settings
 - Momentum in scrolling
 - Experiment with mouse cursor momentum
 - Clamp mouse to screen width and height
 - Option to disable tap to click (or use system setting?)
<3 (COMPLETED) Keyboard mapping of more buttons (enter and escape added, x and o)
 - Custom keyboard mapping?
 - Gamepad text entry the same way Steam Big Picture implements it
 - Analog Stick scrolling option
 - Update mechanism?
 - Trackpad zoom gesture (screen zoom?)
  > http://stackoverflow.com/questions/2487331/is-there-a-way-to-trigger-gesture-events-on-mac-os-x/2489593#2489593

Looking for collaborators and contributors, especially ideas around trackpad
multitouch api design, gesture classifiers and general data massaging to
improve mapping of finger movements to mouse stuff. I'd also like to talk to
any interested user interface designers on designing app interface.


=== Building Info ===
Native extensions (currently ffi, ref, in NodObjC, and node-hid under ds4)
require rebuilding using nw-gyp (available in npm) to be compatible with
node-webkit 0.8.6. To do this for node-hid for example:

  cd node_modules/ds4/node_modules/node-hid
  nw-gyp rebuild --target=0.8.6

The binary components will then be rebuilt. This seems to require Xcode
be installed to build on Mac, not just apple's terminal build tools.

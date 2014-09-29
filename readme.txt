Very early days here! Here be dragons! Pre-alpha experiments

To run this little experiment, first connect a Sony DualShock4 controller via
either USB or Bluetooth, then open this folder with node-webkit 0.8.6-osx-ia32.
The trackpad on the controller should now control your mouse, including tap to
click and press in button clicking, two finger verticle scrolling, and dragging
by pressing in the trackpad button.

Ideas/Todo:
 - Right click via two finger click
 - Right click via two finger tap
 - Figure out why horizontal scrolling doesn't work in NextEvent
 - Retrieve and respect inverted scrolling system setting
 - Key repeat for arrow buttons (menu navigation)
 - Momentum in scrolling
 - Experiment with mouse momentum
 - Clamp mouse to screen width and height
 - Improve tap to click gesture to avoid accidental triggering
 - Keyboard mapping of more buttons
 - Custom keyboard mapping?
 - Steam Big Picture style text entry mode
 - Analog Stick scrolling option
 - Trackpad zoom gesture (screen zoom?)

Looking for collaborators and contributors, especially ideas around trackpad
multitouch api design, gesture classifiers and general data massaging to
improve mapping of finger movements to mouse stuff. I'd also like to talk to
any interested user interface designers on designing app interface
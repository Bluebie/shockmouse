_ = require './node_modules/ds4/node_modules/lodash'
hid = require './node_modules/ds4/node_modules/node-hid'
ds4 = require './node_modules/ds4'

parseDS4HIDData = ds4.parseDS4HIDData

devices = hid.devices()
controller = _(devices).filter(isDS4HID).first()

if (!controller)
  throw new Error('Could not find desired controller.')

hidDevice = new hid.HID(controller.path)
offset = 0

# HIDDesciptor -> Boolean
isDS4HID = (descriptor)-> (descriptor.vendorId == 1356 && descriptor.productId == 1476)

# HIDDesciptor -> Boolean
isBluetoothHID = (descriptor)-> descriptor.path.match(/^Bluetooth/)

# HIDDesciptor -> Boolean
isUSBHID = (descriptor)-> descriptor.path.match(/^USB/)

if (isBluetoothHID(controller))
  offset = 2
  hidDevice.getFeatureReport(0x04, 66)

hidDevice.on 'data', (buf)->
  console.log(parseDS4HIDData(buf.slice(offset)))



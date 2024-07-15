import logging
liquid_logger = logging.getLogger('liquidctl')
liquid_logger.setLevel(logging.CRITICAL)
from liquidctl.driver.corsair_hid_psu import CorsairHidPsuDriver
for dev in CorsairHidPsuDriver.find_supported_devices():
    wattage = dev.get_status()[13][1]
print(wattage)
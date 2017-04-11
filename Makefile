include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ColorCal
ColorCal_FILES = Tweak.xm
ColorCal_FRAMEWORKS = CoreGraphics UIKit EventKit

include $(THEOS_MAKE_PATH)/tweak.mk

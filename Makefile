include $(THEOS)/makefiles/common.mk

TWEAK_NAME = UTMPPCFix

UTMPPCFix_FRAMEWORKS = UIKit Foundation
UTMPPCFix_FILES = Tweak.xm
UTMPPCFix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

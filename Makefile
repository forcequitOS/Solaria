TARGET := appletv:clang:latest:7.0
INSTALL_TARGET_PROCESSES = PineBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Solaria

Solaria_FILES = Tweak.x
Solaria_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
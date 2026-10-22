TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = Waze

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WazePatch

WazePatch_FILES = Tweak.x $(wildcard Sources/*.m)
WazePatch_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/Sources
WazePatch_FRAMEWORKS = UIKit CoreLocation CarPlay AudioToolbox QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = Waze

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WazePatch

WazePatch_FILES = Tweak.x WPPrefs.m WPSpeedometer.m
WazePatch_CFLAGS = -fobjc-arc
WazePatch_FRAMEWORKS = UIKit CoreLocation CarPlay

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += wazepatchprefs
include $(THEOS_MAKE_PATH)/aggregate.mk

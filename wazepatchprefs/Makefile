TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = WazePatchPrefs

WazePatchPrefs_FILES = WPRootListController.m
WazePatchPrefs_FRAMEWORKS = UIKit
WazePatchPrefs_PRIVATE_FRAMEWORKS = Preferences
WazePatchPrefs_INSTALL_PATH = /Library/PreferenceBundles
WazePatchPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

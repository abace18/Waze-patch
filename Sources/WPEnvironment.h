#import <Foundation/Foundation.h>

#define WP_VERSION @"0.3.4"

typedef NS_ENUM(NSInteger, WPInstallMode) {
    WPInstallModeJailbreak, // loaded by the tweak injector from outside the app
    WPInstallModeSideload,  // injected into the IPA, re-signed with a provisioning profile
    WPInstallModeFakesign,  // injected into the IPA, installed via TrollStore/AppSync
};

FOUNDATION_EXPORT WPInstallMode WPCurrentInstallMode(void);
FOUNDATION_EXPORT NSString *WPInstallModeName(WPInstallMode mode);
FOUNDATION_EXPORT NSString *WPWazeVersion(void);

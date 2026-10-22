#import "WPEnvironment.h"
#import <dlfcn.h>

WPInstallMode WPCurrentInstallMode(void) {
    static WPInstallMode mode;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *bundlePath = NSBundle.mainBundle.bundlePath;
        Dl_info info;
        BOOL insideBundle = dladdr((const void *)&WPCurrentInstallMode, &info) && info.dli_fname
            && [@(info.dli_fname) hasPrefix:bundlePath];
        if (!insideBundle) {
            mode = WPInstallModeJailbreak;
        } else if ([NSFileManager.defaultManager fileExistsAtPath:[bundlePath stringByAppendingPathComponent:@"embedded.mobileprovision"]]) {
            mode = WPInstallModeSideload;
        } else {
            mode = WPInstallModeFakesign;
        }
    });
    return mode;
}

NSString *WPInstallModeName(WPInstallMode mode) {
    switch (mode) {
        case WPInstallModeJailbreak: return @"Jailbreak";
        case WPInstallModeSideload: return @"Sideload";
        case WPInstallModeFakesign: return @"TrollStore / AppSync";
    }
    return @"?";
}

NSString *WPWazeVersion(void) {
    return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
}

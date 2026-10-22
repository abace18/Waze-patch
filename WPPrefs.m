#import "WPPrefs.h"

NSString *const WPPrefsChangedNotification = @"WPPrefsChangedNotification";

static BOOL WPBool(NSDictionary *values, NSString *key, BOOL fallback) {
    id value = values[key];
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}

static NSInteger WPInteger(NSDictionary *values, NSString *key, NSInteger fallback, NSInteger min, NSInteger max) {
    id value = values[key];
    NSInteger result = [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : fallback;
    return MAX(min, MIN(max, result));
}

@implementation WPPrefs

+ (instancetype)shared {
    static WPPrefs *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPPrefs new];
        // Must not post here: an observer calling +shared would re-enter dispatch_once.
        [shared loadValues];
    });
    return shared;
}

- (NSDictionary *)readValues {
    CFStringRef domain = (__bridge CFStringRef)WPPrefsDomain;
    CFPreferencesAppSynchronize(domain);

    NSDictionary *values = nil;
    CFArrayRef keys = CFPreferencesCopyKeyList(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keys) {
        values = CFBridgingRelease(CFPreferencesCopyMultiple(keys, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
        CFRelease(keys);
    }
    // cfprefsd may refuse a foreign domain inside the app sandbox; try the file directly.
    if (values.count == 0) {
        values = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" WPPrefsDomain @".plist"];
    }
    return values ?: @{};
}

- (void)reload {
    [self loadValues];
    [[NSNotificationCenter defaultCenter] postNotificationName:WPPrefsChangedNotification object:self];
}

- (void)loadValues {
    NSDictionary *values = [self readValues];

    _enabled = WPBool(values, @"enabled", YES);
    _cpSpeedometer = WPBool(values, @"cpSpeedometer", YES);
    _cpToggleButton = WPBool(values, @"cpToggleButton", YES);
    _speedUnit = (WPSpeedUnit)WPInteger(values, @"speedUnit", WPSpeedUnitKmh, 0, 1);
    _speedCorner = (WPCorner)WPInteger(values, @"speedCorner", WPCornerTopRight, 0, 3);
    _speedScale = WPInteger(values, @"speedScale", 100, 50, 200);
    _speedWarn = WPInteger(values, @"speedWarn", 0, 0, 400);
    _keepAwake = WPBool(values, @"keepAwake", NO);
}

@end

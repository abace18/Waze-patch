#import "WPPrefs.h"

NSString *const WPPrefsChangedNotification = @"WPPrefsChangedNotification";

NSString *const WPKeyPhoneSpeedometer = @"phoneSpeedometer";
NSString *const WPKeyCarSpeedometer = @"carSpeedometer";
NSString *const WPKeyCarToggleButton = @"carToggleButton";
NSString *const WPKeySpeedUnit = @"speedUnit";
NSString *const WPKeyPhoneCorner = @"phoneCorner";
NSString *const WPKeyCarCorner = @"carCorner";
NSString *const WPKeySpeedScale = @"speedScale";
NSString *const WPKeySpeedWarn = @"speedWarn";
NSString *const WPKeyWarnVibrate = @"warnVibrate";
NSString *const WPKeyWarnSound = @"warnSound";
NSString *const WPKeyKeepAwake = @"keepAwake";
NSString *const WPKeyBackgroundAlive = @"backgroundAlive";
NSString *const WPKeyHighRefresh = @"highRefresh";
NSString *const WPKeyLaunchToast = @"launchToast";

@implementation WPPrefs {
    NSUserDefaults *_defaults;
}

+ (instancetype)shared {
    static WPPrefs *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPPrefs new];
    });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.abace.wazepatch"];
        [_defaults registerDefaults:@{
            WPKeyPhoneSpeedometer: @NO,
            WPKeyCarSpeedometer: @YES,
            WPKeyCarToggleButton: @YES,
            WPKeySpeedUnit: @(WPSpeedUnitKmh),
            WPKeyPhoneCorner: @(WPCornerTopRight),
            WPKeyCarCorner: @(WPCornerTopRight),
            WPKeySpeedScale: @100,
            WPKeySpeedWarn: @0,
            WPKeyWarnVibrate: @YES,
            WPKeyWarnSound: @NO,
            WPKeyKeepAwake: @NO,
            WPKeyBackgroundAlive: @NO,
            WPKeyHighRefresh: @NO,
            WPKeyLaunchToast: @YES,
        }];
    }
    return self;
}

- (BOOL)boolForKey:(NSString *)key {
    return [_defaults boolForKey:key];
}

- (NSInteger)integerForKey:(NSString *)key {
    return [_defaults integerForKey:key];
}

- (void)setObject:(id)value forKey:(NSString *)key {
    [_defaults setObject:value forKey:key];
    [[NSNotificationCenter defaultCenter] postNotificationName:WPPrefsChangedNotification object:self];
}

- (BOOL)phoneSpeedometer { return [self boolForKey:WPKeyPhoneSpeedometer]; }
- (BOOL)carSpeedometer { return [self boolForKey:WPKeyCarSpeedometer]; }
- (BOOL)carToggleButton { return [self boolForKey:WPKeyCarToggleButton]; }
- (WPSpeedUnit)speedUnit { return [self integerForKey:WPKeySpeedUnit] == WPSpeedUnitMph ? WPSpeedUnitMph : WPSpeedUnitKmh; }
- (WPCorner)phoneCorner { return (WPCorner)MAX(0, MIN(3, [self integerForKey:WPKeyPhoneCorner])); }
- (WPCorner)carCorner { return (WPCorner)MAX(0, MIN(3, [self integerForKey:WPKeyCarCorner])); }
- (NSInteger)speedScale { return MAX(50, MIN(200, [self integerForKey:WPKeySpeedScale])); }
- (NSInteger)speedWarn { return MAX(0, MIN(300, [self integerForKey:WPKeySpeedWarn])); }
- (BOOL)warnVibrate { return [self boolForKey:WPKeyWarnVibrate]; }
- (BOOL)warnSound { return [self boolForKey:WPKeyWarnSound]; }
- (BOOL)keepAwake { return [self boolForKey:WPKeyKeepAwake]; }
- (BOOL)backgroundAlive { return [self boolForKey:WPKeyBackgroundAlive]; }
- (BOOL)highRefresh { return [self boolForKey:WPKeyHighRefresh]; }
- (BOOL)launchToast { return [self boolForKey:WPKeyLaunchToast]; }

@end

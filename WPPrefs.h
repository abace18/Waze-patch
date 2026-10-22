#import <Foundation/Foundation.h>

#define WPPrefsDomain @"com.abace.wazepatch"
#define WPPrefsDarwinNotification "com.abace.wazepatch/prefs"

// Posted on the main thread after the preferences have been reloaded.
FOUNDATION_EXPORT NSString *const WPPrefsChangedNotification;

typedef NS_ENUM(NSInteger, WPSpeedUnit) {
    WPSpeedUnitKmh = 0,
    WPSpeedUnitMph = 1,
};

typedef NS_ENUM(NSInteger, WPCorner) {
    WPCornerTopLeft = 0,
    WPCornerTopRight = 1,
    WPCornerBottomLeft = 2,
    WPCornerBottomRight = 3,
};

@interface WPPrefs : NSObject
+ (instancetype)shared;
- (void)reload;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) BOOL cpSpeedometer;
@property (nonatomic, readonly) BOOL cpToggleButton;
@property (nonatomic, readonly) WPSpeedUnit speedUnit;
@property (nonatomic, readonly) WPCorner speedCorner;
@property (nonatomic, readonly) NSInteger speedScale; // percent
@property (nonatomic, readonly) NSInteger speedWarn;  // in the selected unit, 0 = off
@property (nonatomic, readonly) BOOL keepAwake;
@end

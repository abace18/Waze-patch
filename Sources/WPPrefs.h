#import <Foundation/Foundation.h>

// Posted on the main thread whenever a setting changes.
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

FOUNDATION_EXPORT NSString *const WPKeyPhoneSpeedometer;
FOUNDATION_EXPORT NSString *const WPKeyCarSpeedometer;
FOUNDATION_EXPORT NSString *const WPKeyCarToggleButton;
FOUNDATION_EXPORT NSString *const WPKeySpeedUnit;
FOUNDATION_EXPORT NSString *const WPKeyPhoneCorner;
FOUNDATION_EXPORT NSString *const WPKeyCarCorner;
FOUNDATION_EXPORT NSString *const WPKeySpeedScale;
FOUNDATION_EXPORT NSString *const WPKeySpeedWarn;
FOUNDATION_EXPORT NSString *const WPKeyWarnVibrate;
FOUNDATION_EXPORT NSString *const WPKeyWarnSound;
FOUNDATION_EXPORT NSString *const WPKeyKeepAwake;
FOUNDATION_EXPORT NSString *const WPKeyBackgroundAlive;
FOUNDATION_EXPORT NSString *const WPKeyHighRefresh;
FOUNDATION_EXPORT NSString *const WPKeyLaunchToast;

// Settings live in the app's own container, so they work the same on
// jailbreak and in an injected IPA.
@interface WPPrefs : NSObject
+ (instancetype)shared;

- (BOOL)boolForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;

@property (nonatomic, readonly) BOOL phoneSpeedometer;
@property (nonatomic, readonly) BOOL carSpeedometer;
@property (nonatomic, readonly) BOOL carToggleButton;
@property (nonatomic, readonly) WPSpeedUnit speedUnit;
@property (nonatomic, readonly) WPCorner phoneCorner;
@property (nonatomic, readonly) WPCorner carCorner;
@property (nonatomic, readonly) NSInteger speedScale; // percent
@property (nonatomic, readonly) NSInteger speedWarn;  // in the selected unit, 0 = off
@property (nonatomic, readonly) BOOL warnVibrate;
@property (nonatomic, readonly) BOOL warnSound;
@property (nonatomic, readonly) BOOL keepAwake;
@property (nonatomic, readonly) BOOL backgroundAlive;
@property (nonatomic, readonly) BOOL highRefresh;
@property (nonatomic, readonly) BOOL launchToast;
@end

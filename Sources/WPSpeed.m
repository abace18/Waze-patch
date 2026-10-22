#import "WPSpeed.h"
#import "WPPrefs.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreLocation/CoreLocation.h>

NSString *const WPSpeedDidChangeNotification = @"WPSpeedDidChangeNotification";

static const SystemSoundID kWPWarnSound = 1005;

static BOOL WPAppSupportsBackgroundLocation(void) {
    NSArray *modes = [NSBundle.mainBundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    return [modes isKindOfClass:NSArray.class] && [modes containsObject:@"location"];
}

@interface WPSpeed () <CLLocationManagerDelegate>
@end

@implementation WPSpeed {
    CLLocationManager *_manager;
    NSMutableSet<NSString *> *_consumers;
    BOOL _updating;
    CLLocationSpeed _speed; // m/s, negative when unknown
}

+ (instancetype)shared {
    static WPSpeed *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPSpeed new];
    });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _speed = -1;
        _consumers = [NSMutableSet set];
    }
    return self;
}

- (void)addConsumer:(NSString *)name {
    [_consumers addObject:name];
    [self updateRunning];
}

- (void)removeConsumer:(NSString *)name {
    [_consumers removeObject:name];
    [self updateRunning];
}

- (void)updateRunning {
    BOOL wanted = _consumers.count > 0;
    if (wanted && !_updating) {
        if (!_manager) {
            _manager = [CLLocationManager new];
            _manager.delegate = self;
            _manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            _manager.activityType = CLActivityTypeAutomotiveNavigation;
            _manager.pausesLocationUpdatesAutomatically = NO;
            // CarPlay usually runs with the phone app in the background.
            if (WPAppSupportsBackgroundLocation()) _manager.allowsBackgroundLocationUpdates = YES;
        }
        [_manager startUpdatingLocation];
        _updating = YES;
    } else if (!wanted && _updating) {
        [_manager stopUpdatingLocation];
        _updating = NO;
        _speed = -1;
        _overLimit = NO;
        [self post];
    }
}

- (NSInteger)displaySpeed {
    if (_speed < 0) return -1;
    double value = _speed * (WPPrefs.shared.speedUnit == WPSpeedUnitMph ? 2.23694 : 3.6);
    return value < 3 ? 0 : lround(value); // hide GPS jitter while stopped
}

- (void)evaluateLimit {
    WPPrefs *prefs = WPPrefs.shared;
    NSInteger limit = prefs.speedWarn;
    NSInteger shown = self.displaySpeed;
    if (limit <= 0 || shown < 0) {
        _overLimit = NO;
        return;
    }
    if (!_overLimit && shown > limit) {
        _overLimit = YES;
        if (prefs.warnVibrate) AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        if (prefs.warnSound) AudioServicesPlaySystemSound(kWPWarnSound);
    } else if (_overLimit && shown < limit - 2) {
        // Small hysteresis so hovering around the limit doesn't buzz repeatedly.
        _overLimit = NO;
    }
}

- (void)post {
    [[NSNotificationCenter defaultCenter] postNotificationName:WPSpeedDidChangeNotification object:self];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) return;
    _lastLocation = location;
    _speed = location.speed;
    [self evaluateLimit];
    [self post];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    _speed = -1;
    _overLimit = NO;
    [self post];
}

@end

#import "WPSpeedometer.h"
#import "WPPrefs.h"
#import <CoreLocation/CoreLocation.h>

static BOOL WPAppSupportsBackgroundLocation(void) {
    NSArray *modes = [NSBundle.mainBundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    return [modes isKindOfClass:NSArray.class] && [modes containsObject:@"location"];
}

@interface WPSpeedometer () <CLLocationManagerDelegate>
@end

@implementation WPSpeedometer {
    CLLocationManager *_locationManager;
    BOOL _updating;
    CLLocationSpeed _lastSpeed; // m/s, negative when unknown
    UIView *_container;
    UILabel *_speedLabel;
    UILabel *_unitLabel;
    NSArray<NSLayoutConstraint *> *_constraints;
    BOOL _layoutDirty;
}

+ (instancetype)shared {
    static WPSpeedometer *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPSpeedometer new];
    });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _lastSpeed = -1;
        _layoutDirty = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged) name:WPPrefsChangedNotification object:nil];
    }
    return self;
}

- (BOOL)shouldShow {
    WPPrefs *prefs = WPPrefs.shared;
    return prefs.enabled && prefs.cpSpeedometer && !_userHidden;
}

#pragma mark - Window lifecycle

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;
    if (_window != window) {
        [self detach];
        _window = window;
        _layoutDirty = YES;
        NSLog(@"[WazePatch] attached to CarPlay window %@", window);
    }
    [self refresh];
}

- (void)windowDidLayout:(UIWindow *)window {
    if (window != _window) {
        [self attachToWindow:window];
        return;
    }
    // Waze may add views after ours; keep the overlay on top.
    if (_container.superview == window && window.subviews.lastObject != _container) {
        [window bringSubviewToFront:_container];
    }
}

- (void)detach {
    [_container removeFromSuperview];
    _window = nil;
    [self updateLocationUpdates];
}

- (void)setUserHidden:(BOOL)userHidden {
    _userHidden = userHidden;
    [self refresh];
}

- (void)prefsChanged {
    _layoutDirty = YES;
    [self refresh];
}

- (void)refresh {
    UIWindow *window = _window;
    if (!window || ![self shouldShow]) {
        [_container removeFromSuperview];
        [self updateLocationUpdates];
        return;
    }

    [self buildViewsIfNeeded];
    if (_container.superview != window) {
        [_container removeFromSuperview];
        [window addSubview:_container];
        _layoutDirty = YES;
    }
    if (_layoutDirty) {
        [self applyLayout];
        _layoutDirty = NO;
    }
    [window bringSubviewToFront:_container];
    [self render];
    [self updateLocationUpdates];
}

#pragma mark - Views

- (void)buildViewsIfNeeded {
    if (_container) return;

    _container = [UIView new];
    _container.translatesAutoresizingMaskIntoConstraints = NO;
    _container.userInteractionEnabled = NO;
    _container.layer.masksToBounds = YES;

    _speedLabel = [UILabel new];
    _speedLabel.textColor = UIColor.whiteColor;
    _speedLabel.textAlignment = NSTextAlignmentCenter;
    _speedLabel.adjustsFontSizeToFitWidth = YES;
    _speedLabel.minimumScaleFactor = 0.5;

    _unitLabel = [UILabel new];
    _unitLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    _unitLabel.textAlignment = NSTextAlignmentCenter;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_speedLabel, _unitLabel]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    [_container addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:_container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:_container.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:_container.leadingAnchor constant:4],
    ]];
}

- (void)applyLayout {
    UIWindow *window = _window;
    if (!window || _container.superview != window) return;

    WPPrefs *prefs = WPPrefs.shared;
    CGFloat scale = prefs.speedScale / 100.0;
    _speedLabel.font = [UIFont monospacedDigitSystemFontOfSize:30 * scale weight:UIFontWeightBold];
    _unitLabel.font = [UIFont systemFontOfSize:11 * scale weight:UIFontWeightSemibold];
    _container.layer.cornerRadius = 14 * scale;

    if (_constraints) [NSLayoutConstraint deactivateConstraints:_constraints];

    UILayoutGuide *guide = window.safeAreaLayoutGuide;
    BOOL top = prefs.speedCorner == WPCornerTopLeft || prefs.speedCorner == WPCornerTopRight;
    BOOL left = prefs.speedCorner == WPCornerTopLeft || prefs.speedCorner == WPCornerBottomLeft;
    CGFloat margin = 8;
    _constraints = @[
        [_container.widthAnchor constraintEqualToConstant:78 * scale],
        [_container.heightAnchor constraintEqualToConstant:60 * scale],
        top ? [_container.topAnchor constraintEqualToAnchor:guide.topAnchor constant:margin]
            : [_container.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-margin],
        left ? [_container.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:margin]
             : [_container.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-margin],
    ];
    [NSLayoutConstraint activateConstraints:_constraints];
}

- (void)render {
    if (!_container) return;

    WPPrefs *prefs = WPPrefs.shared;
    BOOL mph = prefs.speedUnit == WPSpeedUnitMph;
    _unitLabel.text = mph ? @"mph" : @"km/h";

    UIColor *normal = [UIColor colorWithWhite:0 alpha:0.7];
    if (_lastSpeed < 0) {
        _speedLabel.text = @"--";
        _container.backgroundColor = normal;
        return;
    }

    double value = _lastSpeed * (mph ? 2.23694 : 3.6);
    NSInteger shown = value < 3 ? 0 : lround(value); // hide GPS jitter while stopped
    _speedLabel.text = [NSString stringWithFormat:@"%ld", (long)shown];

    BOOL over = prefs.speedWarn > 0 && shown > prefs.speedWarn;
    _container.backgroundColor = over ? [UIColor colorWithRed:0.85 green:0.1 blue:0.1 alpha:0.9] : normal;
}

#pragma mark - Location

- (void)updateLocationUpdates {
    BOOL wanted = _window && _container.superview && [self shouldShow];
    if (wanted && !_updating) {
        if (!_locationManager) {
            _locationManager = [CLLocationManager new];
            _locationManager.delegate = self;
            _locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
            _locationManager.activityType = CLActivityTypeAutomotiveNavigation;
            _locationManager.pausesLocationUpdatesAutomatically = NO;
            // CarPlay usually runs with the phone app in the background.
            if (WPAppSupportsBackgroundLocation()) _locationManager.allowsBackgroundLocationUpdates = YES;
        }
        [_locationManager startUpdatingLocation];
        _updating = YES;
    } else if (!wanted && _updating) {
        [_locationManager stopUpdatingLocation];
        _updating = NO;
        _lastSpeed = -1;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) return;
    _lastSpeed = location.speed;
    [self render];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    _lastSpeed = -1;
    [self render];
}

@end

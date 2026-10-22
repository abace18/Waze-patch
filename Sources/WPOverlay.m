#import "WPOverlay.h"
#import "WPPrefs.h"
#import "WPSpeed.h"
#import "WPSpeedometerView.h"

@interface WPOverlaySlot : NSObject
@property (nonatomic, copy) NSString *consumer;
// The phone badge goes into the root view so Waze's full-screen menus cover it;
// on CarPlay the whole window is the map, so it goes on the window itself.
@property (nonatomic) BOOL useRootView;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic) BOOL enabled;
@property (nonatomic, strong) WPSpeedometerView *view;
@property (nonatomic, copy) NSArray<NSLayoutConstraint *> *constraints;
@property (nonatomic) WPCorner layoutCorner;
@property (nonatomic) CGFloat layoutScale;
@end

@implementation WPOverlaySlot

- (UIView *)container {
    UIWindow *window = self.window;
    return self.useRootView ? window.rootViewController.view : window;
}

@end

static NSArray<NSLayoutConstraint *> *WPCornerConstraints(UIView *view, UILayoutGuide *guide, WPCorner corner) {
    BOOL top = corner == WPCornerTopLeft || corner == WPCornerTopRight;
    BOOL left = corner == WPCornerTopLeft || corner == WPCornerBottomLeft;
    CGFloat margin = 8;
    return @[
        top ? [view.topAnchor constraintEqualToAnchor:guide.topAnchor constant:margin]
            : [view.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-margin],
        left ? [view.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:margin]
             : [view.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-margin],
    ];
}

@implementation WPOverlay {
    WPOverlaySlot *_phone;
    WPOverlaySlot *_car;
}

+ (instancetype)shared {
    static WPOverlay *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPOverlay new];
    });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _phone = [WPOverlaySlot new];
        _phone.consumer = @"phone";
        _phone.useRootView = YES;
        _car = [WPOverlaySlot new];
        _car.consumer = @"car";

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(refresh) name:WPPrefsChangedNotification object:nil];
        [center addObserver:self selector:@selector(speedChanged) name:WPSpeedDidChangeNotification object:nil];
    }
    return self;
}

- (void)setPhoneWindow:(UIWindow *)window {
    [self moveSlot:_phone toWindow:window];
}

- (void)setCarWindow:(UIWindow *)window {
    [self moveSlot:_car toWindow:window];
}

- (void)carWindowGone {
    [self moveSlot:_car toWindow:nil];
}

- (void)setCarHidden:(BOOL)carHidden {
    _carHidden = carHidden;
    [self refresh];
}

- (void)moveSlot:(WPOverlaySlot *)slot toWindow:(UIWindow *)window {
    if (slot.window == window) return;
    [slot.view removeFromSuperview];
    slot.window = window;
    [self refresh];
}

- (void)refresh {
    WPPrefs *prefs = WPPrefs.shared;
    CGFloat scale = prefs.speedScale / 100.0;
    [self refreshSlot:_phone enabled:prefs.phoneSpeedometer corner:prefs.phoneCorner scale:scale];
    [self refreshSlot:_car enabled:prefs.carSpeedometer && !_carHidden corner:prefs.carCorner scale:scale];
}

- (void)refreshSlot:(WPOverlaySlot *)slot enabled:(BOOL)enabled corner:(WPCorner)corner scale:(CGFloat)scale {
    slot.enabled = enabled;
    UIView *container = slot.container;
    if (!container || !enabled) {
        [slot.view removeFromSuperview];
        [WPSpeed.shared removeConsumer:slot.consumer];
        return;
    }

    if (!slot.view) slot.view = [WPSpeedometerView new];
    if (slot.view.superview != container) {
        [slot.view removeFromSuperview];
        [container addSubview:slot.view];
        slot.constraints = nil;
    }
    if (!slot.constraints || slot.layoutCorner != corner || slot.layoutScale != scale) {
        if (slot.constraints) [NSLayoutConstraint deactivateConstraints:slot.constraints];
        [slot.view applyScale:scale];
        slot.constraints = WPCornerConstraints(slot.view, container.safeAreaLayoutGuide, corner);
        [NSLayoutConstraint activateConstraints:slot.constraints];
        slot.layoutCorner = corner;
        slot.layoutScale = scale;
    }
    [container bringSubviewToFront:slot.view];
    [slot.view refresh];
    [WPSpeed.shared addConsumer:slot.consumer];
}

- (void)windowDidLayout:(UIWindow *)window {
    for (WPOverlaySlot *slot in @[_phone, _car]) {
        if (slot.window != window || !slot.enabled) continue;
        UIView *container = slot.container;
        if (container && slot.view.superview != container) {
            // The root view wasn't ready yet, or Waze swapped it; (re)attach.
            [self refresh];
            return;
        }
        [self bringToFront:slot];
    }
}

- (void)bringToFront:(WPOverlaySlot *)slot {
    UIView *container = slot.view.superview;
    // Waze may add views after ours; keep the badge on top.
    if (container && container.subviews.lastObject != slot.view) [container bringSubviewToFront:slot.view];
}

- (void)speedChanged {
    for (WPOverlaySlot *slot in @[_phone, _car]) {
        [slot.view refresh];
        [self bringToFront:slot];
    }
}

@end

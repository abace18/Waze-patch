#import "WPDimmer.h"
#import "WPPrefs.h"

@implementation WPDimmer {
    __weak UIWindow *_phoneWindow;
    __weak UIWindow *_carWindow;
    UIView *_phoneView;
    UIView *_carView;
}

+ (instancetype)shared {
    static WPDimmer *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [WPDimmer new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh)
                                                     name:WPPrefsChangedNotification object:nil];
    }
    return self;
}

- (UIView *)makeOverlay {
    UIView *view = [UIView new];
    view.userInteractionEnabled = NO;       // taps go through to the map
    view.backgroundColor = UIColor.blackColor;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}

- (void)setPhoneWindow:(UIWindow *)window {
    if (_phoneWindow == window) { [self refresh]; return; }
    [_phoneView removeFromSuperview];
    _phoneView = nil;
    _phoneWindow = window;
    [self refresh];
}

- (void)setCarWindow:(UIWindow *)window {
    if (_carWindow == window) { [self refresh]; return; }
    [_carView removeFromSuperview];
    _carView = nil;
    _carWindow = window;
    [self refresh];
}

- (void)carWindowGone {
    [_carView removeFromSuperview];
    _carView = nil;
    _carWindow = nil;
}

- (void)refresh {
    WPPrefs *prefs = WPPrefs.shared;
    CGFloat alpha = prefs.dimmer ? MAX(0, MIN(90, prefs.dimmerIntensity)) / 100.0 : 0;
    [self applyAlpha:alpha toWindow:_phoneWindow viewRef:&_phoneView];
    [self applyAlpha:alpha toWindow:_carWindow viewRef:&_carView];
}

- (void)applyAlpha:(CGFloat)alpha toWindow:(UIWindow *)window viewRef:(UIView * __strong *)viewRef {
    if (!window || alpha <= 0) {
        [*viewRef removeFromSuperview];
        *viewRef = nil;
        return;
    }
    if (!*viewRef) *viewRef = [self makeOverlay];
    UIView *view = *viewRef;
    if (view.superview != window) {
        [view removeFromSuperview];
        [window addSubview:view];
        [NSLayoutConstraint activateConstraints:@[
            [view.topAnchor constraintEqualToAnchor:window.topAnchor],
            [view.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
            [view.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
            [view.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
        ]];
    }
    view.alpha = alpha;
    [window bringSubviewToFront:view];
}

- (void)windowDidLayout:(UIWindow *)window {
    UIView *view = window == _phoneWindow ? _phoneView : window == _carWindow ? _carView : nil;
    // Stay just below our other overlays but above Waze; simplest is top, then
    // WPOverlay re-fronts its speed badge on its own layout pass.
    if (view && view.superview == window && window.subviews.lastObject != view) {
        [window bringSubviewToFront:view];
    }
}

@end

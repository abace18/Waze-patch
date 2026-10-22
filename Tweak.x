#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "WPDimmer.h"
#import "WPEnvironment.h"
#import "WPLaneGuidance.h"
#import "WPOverlay.h"
#import "WPPrefs.h"
#import "WPSettingsViewController.h"
#import "WPSpeed.h"
#import "WPToast.h"
#import "WPTripLog.h"

// Everything here hooks public Apple APIs (UIKit, CarPlay, QuartzCore), so it
// does not depend on Waze's private classes and survives Waze updates.

static char kWPOwnedButtonKey;
static char kWPGestureKey;
static NSHashTable<CPMapTemplate *> *gMapTemplates;
static BOOL gAppWantsIdleTimerDisabled;

static UIWindow *WPKeyWindow(void) {
    UIWindow *fallback = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
            if (!fallback && window.windowLevel == UIWindowLevelNormal) fallback = window;
        }
    }
    return fallback;
}

#pragma mark - Settings gesture

@interface WPGestureHandler : NSObject <UIGestureRecognizerDelegate>
@end

@implementation WPGestureHandler

+ (instancetype)shared {
    static WPGestureHandler *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [WPGestureHandler new];
    });
    return shared;
}

- (void)handle:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSLog(@"[WazePatch] settings gesture fired");
        [WPSettingsViewController presentInWindow:(gesture.view.window ?: WPKeyWindow())];
    }
}

// Recognize alongside Waze's own map gestures, and never let them require us to fail.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

@end

static void WPInstallSettingsGesture(UIWindow *window) {
    if (objc_getAssociatedObject(window, &kWPGestureKey)) return;
    UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:WPGestureHandler.shared
                                                                                          action:@selector(handle:)];
    gesture.numberOfTouchesRequired = 3;
    gesture.minimumPressDuration = 0.5;
    // The map drifts under three fingers; don't cancel the press over that.
    gesture.allowableMovement = 200;
    gesture.cancelsTouchesInView = NO;
    gesture.delaysTouchesBegan = NO;
    gesture.delaysTouchesEnded = NO;
    gesture.delegate = WPGestureHandler.shared;
    [window addGestureRecognizer:gesture];
    objc_setAssociatedObject(window, &kWPGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[WazePatch] settings gesture installed on %@", window);
}

#pragma mark - Windows

static BOOL WPIsMainCarPlayWindow(UIWindow *window) {
    UIWindowScene *scene = window.windowScene;
    return [scene isKindOfClass:CPTemplateApplicationScene.class]
        && ((CPTemplateApplicationScene *)scene).carWindow == window;
}

static BOOL WPIsPhoneMainWindow(UIWindow *window) {
    if ([window.windowScene isKindOfClass:CPTemplateApplicationScene.class]) return NO;
    if (window.windowLevel != UIWindowLevelNormal) return NO;
    UIWindowScene *scene = window.windowScene;
    return !scene || [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication];
}

static void WPPhoneWindowBecameKey(UIWindow *window) {
    WPInstallSettingsGesture(window);
    // Dimmer first (lower), speed badge after (stays on top).
    [WPDimmer.shared setPhoneWindow:window];
    [WPOverlay.shared setPhoneWindow:window];

    static BOOL toastShown;
    if (!toastShown && WPPrefs.shared.launchToast) {
        toastShown = YES;
        NSString *text = [NSString stringWithFormat:@"WazePatch %@ activ · %@", WP_VERSION, WPInstallModeName(WPCurrentInstallMode())];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [WPToast showText:text inWindow:window];
        });
    }
}

static void WPAttachToCarPlayScene(UIScene *scene) {
    if (![scene isKindOfClass:CPTemplateApplicationScene.class]) return;
    UIWindow *window = ((CPTemplateApplicationScene *)scene).carWindow;
    if (window) {
        [WPDimmer.shared setCarWindow:window];
        [WPOverlay.shared setCarWindow:window];
    }
}

#pragma mark - CarPlay map button

static CPMapButton *WPMakeToggleButton(void) {
    CPMapButton *button = [[CPMapButton alloc] initWithHandler:^(CPMapButton *mapButton) {
        WPOverlay.shared.carHidden = !WPOverlay.shared.carHidden;
    }];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold];
    button.image = [UIImage systemImageNamed:@"speedometer" withConfiguration:config];
    objc_setAssociatedObject(button, &kWPOwnedButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return button;
}

static void WPRefreshMapTemplates(void) {
    for (CPMapTemplate *mapTemplate in gMapTemplates.allObjects) {
        // Goes through the hook below, which re-filters our button.
        mapTemplate.mapButtons = mapTemplate.mapButtons;
    }
}

#pragma mark - System

static void WPApplyKeepAwake(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (app) app.idleTimerDisabled = gAppWantsIdleTimerDisabled;
}

static void WPApplyBackgroundAlive(void) {
    // A running location session keeps Waze alive in the background.
    if (WPPrefs.shared.backgroundAlive) {
        [WPSpeed.shared addConsumer:@"background"];
    } else {
        [WPSpeed.shared removeConsumer:@"background"];
    }
}

#pragma mark - Hooks

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    if (WPIsPhoneMainWindow(self)) WPPhoneWindowBecameKey(self);
}

// Fallback trigger: shake the phone to open the settings, in case the
// 3-finger press is swallowed by Waze's map gestures.
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake && WPIsPhoneMainWindow(self)) {
        NSLog(@"[WazePatch] shake -> settings");
        [WPSettingsViewController presentInWindow:self];
    }
}

- (void)layoutSubviews {
    %orig;
    if (WPIsMainCarPlayWindow(self)) {
        [WPDimmer.shared setCarWindow:self];
        [WPOverlay.shared setCarWindow:self];
    }
    // Dimmer first (lower), speed badge last (stays on top).
    [WPDimmer.shared windowDidLayout:self];
    [WPOverlay.shared windowDidLayout:self];
}

%end

%hook CPMapTemplate

- (void)setMapButtons:(NSArray<CPMapButton *> *)mapButtons {
    [gMapTemplates addObject:self];

    NSMutableArray<CPMapButton *> *buttons = [NSMutableArray array];
    for (CPMapButton *button in mapButtons) {
        if (!objc_getAssociatedObject(button, &kWPOwnedButtonKey)) [buttons addObject:button];
    }
    WPPrefs *prefs = WPPrefs.shared;
    // CarPlay allows at most four map buttons; never push one of Waze's out.
    if (prefs.carSpeedometer && prefs.carToggleButton && buttons.count < 4) {
        [buttons addObject:WPMakeToggleButton()];
    }
    %orig([buttons copy]);
}

%end

%hook UIApplication

- (void)setIdleTimerDisabled:(BOOL)disabled {
    gAppWantsIdleTimerDisabled = disabled;
    %orig(disabled || WPPrefs.shared.keepAwake);
}

%end

// ProMotion: lift the 60 Hz cap iOS applies to apps on iPhone and ask for the
// highest rate wherever Waze sets one. Read once at launch.
%group HighRefresh

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (self == NSBundle.mainBundle && [key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"]) return @YES;
    return %orig;
}

%end

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)framesPerSecond {
    %orig(0); // 0 = the display's maximum
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    %orig(CAFrameRateRangeMake(80, 120, 120));
}

%end

%end

%ctor {
    @autoreleasepool {
        // The filter plist limits loading to Waze on jailbreak; in an injected IPA the
        // bundle id may be changed, so only skip app extensions (widgets etc.).
        if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]) return;

        gMapTemplates = [NSHashTable weakObjectsHashTable];
        WPPrefs *prefs = WPPrefs.shared;

        %init;
        if (prefs.highRefresh) %init(HighRefresh);

        // Install as early as possible so config reads at launch are caught too.
        [WPLaneGuidance installIfEnabled];

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        NSOperationQueue *main = NSOperationQueue.mainQueue;
        [center addObserverForName:UISceneDidActivateNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPAttachToCarPlayScene(note.object);
        }];
        [center addObserverForName:UISceneWillEnterForegroundNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPAttachToCarPlayScene(note.object);
        }];
        [center addObserverForName:UISceneDidDisconnectNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            if ([note.object isKindOfClass:CPTemplateApplicationScene.class]) {
                [WPOverlay.shared carWindowGone];
                [WPDimmer.shared carWindowGone];
            }
        }];
        [center addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPApplyBackgroundAlive();
            [WPTripLog.shared applyPrefs];
            [WPLaneGuidance installIfEnabled];
        }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPApplyKeepAwake();
        }];
        [center addObserverForName:WPPrefsChangedNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPApplyKeepAwake();
            WPApplyBackgroundAlive();
            [WPTripLog.shared applyPrefs];
            WPRefreshMapTemplates();
        }];

        NSLog(@"[WazePatch] %@ loaded into Waze %@ (%@)", WP_VERSION, WPWazeVersion(), WPInstallModeName(WPCurrentInstallMode()));
    }
}

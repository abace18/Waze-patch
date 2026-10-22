#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import <objc/runtime.h>
#import "WPPrefs.h"
#import "WPSpeedometer.h"

// Everything here hooks public Apple APIs (CarPlay, UIKit), so it does not
// depend on Waze's private classes and survives Waze updates.

static char kWPOwnedButtonKey;
static NSHashTable<CPMapTemplate *> *gMapTemplates;
static BOOL gAppWantsIdleTimerDisabled;

static BOOL WPIsMainCarPlayWindow(UIWindow *window) {
    UIWindowScene *scene = window.windowScene;
    return [scene isKindOfClass:CPTemplateApplicationScene.class]
        && ((CPTemplateApplicationScene *)scene).carWindow == window;
}

static void WPAttachToCarPlayScene(UIScene *scene) {
    if (![scene isKindOfClass:CPTemplateApplicationScene.class]) return;
    UIWindow *window = ((CPTemplateApplicationScene *)scene).carWindow;
    if (window) [WPSpeedometer.shared attachToWindow:window];
}

static CPMapButton *WPMakeToggleButton(void) {
    CPMapButton *button = [[CPMapButton alloc] initWithHandler:^(CPMapButton *mapButton) {
        WPSpeedometer *speedometer = WPSpeedometer.shared;
        speedometer.userHidden = !speedometer.userHidden;
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

static void WPApplyKeepAwake(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (app) app.idleTimerDisabled = gAppWantsIdleTimerDisabled;
}

%hook CPMapTemplate

- (void)setMapButtons:(NSArray<CPMapButton *> *)mapButtons {
    [gMapTemplates addObject:self];

    NSMutableArray<CPMapButton *> *buttons = [NSMutableArray array];
    for (CPMapButton *button in mapButtons) {
        if (!objc_getAssociatedObject(button, &kWPOwnedButtonKey)) [buttons addObject:button];
    }
    WPPrefs *prefs = WPPrefs.shared;
    // CarPlay allows at most four map buttons; never push one of Waze's out.
    if (prefs.enabled && prefs.cpSpeedometer && prefs.cpToggleButton && buttons.count < 4) {
        [buttons addObject:WPMakeToggleButton()];
    }
    %orig([buttons copy]);
}

%end

%hook CPWindow

- (void)setRootViewController:(UIViewController *)rootViewController {
    %orig;
    if (WPIsMainCarPlayWindow(self)) [WPSpeedometer.shared attachToWindow:self];
}

- (void)layoutSubviews {
    %orig;
    if (WPIsMainCarPlayWindow(self)) [WPSpeedometer.shared windowDidLayout:self];
}

%end

%hook UIApplication

- (void)setIdleTimerDisabled:(BOOL)disabled {
    gAppWantsIdleTimerDisabled = disabled;
    WPPrefs *prefs = WPPrefs.shared;
    %orig(disabled || (prefs.enabled && prefs.keepAwake));
}

%end

static void WPPrefsDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [WPPrefs.shared reload];
    });
}

%ctor {
    @autoreleasepool {
        // The filter plist limits loading to Waze on jailbreak; in an injected IPA the
        // bundle id may be changed, so only skip app extensions (widgets etc.).
        if ([NSBundle.mainBundle.bundlePath hasSuffix:@".appex"]) return;

        gMapTemplates = [NSHashTable weakObjectsHashTable];
        [WPPrefs shared];
        %init;

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, WPPrefsDarwinCallback,
                                        CFSTR(WPPrefsDarwinNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);

        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        NSOperationQueue *main = NSOperationQueue.mainQueue;
        [center addObserverForName:UISceneDidActivateNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPAttachToCarPlayScene(note.object);
        }];
        [center addObserverForName:UISceneWillEnterForegroundNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPAttachToCarPlayScene(note.object);
        }];
        [center addObserverForName:UISceneDidDisconnectNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            if (![note.object isKindOfClass:CPTemplateApplicationScene.class]) return;
            UIWindow *window = WPSpeedometer.shared.window;
            if (!window || !window.windowScene || window.windowScene == note.object) [WPSpeedometer.shared detach];
        }];
        [center addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPApplyKeepAwake();
        }];
        [center addObserverForName:WPPrefsChangedNotification object:nil queue:main usingBlock:^(NSNotification *note) {
            WPApplyKeepAwake();
            WPRefreshMapTemplates();
        }];

        NSLog(@"[WazePatch] loaded into Waze %@", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);
    }
}

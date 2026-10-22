#import "WPLaneGuidance.h"
#import "WPPrefs.h"
#import <objc/runtime.h>

// Diagnostics shown in-app so the user doesn't need Console.
static BOOL gInstalled;
static NSInteger gHookedClasses;
static NSInteger gHits; // how many lane-guidance reads we forced

// The iOS config keys that gate lane guidance, as found in the 5.26 binary.
static NSSet<NSString *> *WPLaneKeys(void) {
    static NSSet *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = [NSSet setWithArray:@[
            @"enable_turn_card_lane_guidance",
            @"enable_in_moment_lane_guidance",
            @"enable_enhanced_lane_guidance",
            @"enable_continuous_lane_guidance",
            @"enable_fnm_continuous_lane_guidance",
            @"enable_mid_step_continue_straight_guidance",
            @"enable_continue_straight_highway_canned_messages",
            @"want_lane_guidance",
            @"include_lane_guidance",
            @"lane_guidance",
        ]];
    });
    return keys;
}

static BOOL WPKeyMatches(id key) {
    if (![key isKindOfClass:NSString.class]) return NO;
    NSString *s = key;
    if ([WPLaneKeys() containsObject:s]) return YES;
    // Be lenient: any lane-guidance enable flag.
    return [s containsString:@"lane_guidance"] || [s containsString:@"continue_straight"];
}

typedef BOOL (*WPBoolIMP)(id, SEL, id);

static void WPSwizzleBoolForKey(Class cls) {
    SEL sel = @selector(boolForKey:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    // Only touch methods that actually return a BOOL/char and take one object.
    const char *enc = method_getTypeEncoding(m);
    if (!enc || (enc[0] != 'c' && enc[0] != 'B')) return;

    __block WPBoolIMP orig = (WPBoolIMP)method_getImplementation(m);
    IMP replacement = imp_implementationWithBlock(^BOOL(id self, id key) {
        if (WPKeyMatches(key)) { gHits++; return YES; }
        return orig(self, sel, key);
    });
    method_setImplementation(m, replacement);
    NSLog(@"[WazePatch] lane guidance: hooked -[%s boolForKey:]", class_getName(cls));
}

@implementation WPLaneGuidance

+ (void)installIfEnabled {
    if (!WPPrefs.shared.laneGuidance) return;

    // Swizzle boolForKey: on Waze's config classes only (never NSUserDefaults etc.).
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSInteger hooked = 0;
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        NSString *n = @(name);
        if (![n containsString:@"ConfigService"] && ![n containsString:@"ConfigFeatureManager"]) continue;
        WPSwizzleBoolForKey(classes[i]);
        hooked++;
    }
    free(classes);
    gInstalled = YES;
    gHookedClasses = hooked;
    NSLog(@"[WazePatch] lane guidance enabled, hooked config classes: %ld", (long)hooked);
}

+ (NSString *)statusSummary {
    if (!WPPrefs.shared.laneGuidance) return @"Oprit";
    if (!gInstalled) return @"Repornește Waze";
    return [NSString stringWithFormat:@"%ld clase · %ld citiri forțate", (long)gHookedClasses, (long)gHits];
}

@end

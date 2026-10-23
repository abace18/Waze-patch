#import "WPLaneGuidance.h"
#import "WPPrefs.h"
#import <objc/runtime.h>

// Lightweight: only hooks boolForKey: on Waze's config classes and does a cheap
// string check. No work on non-string keys, so it can't burn CPU on the app's
// frequent config reads. (An earlier diagnostic observed every accessor and
// built a description per read, which overheated the device.)
static BOOL gInstalled;
static BOOL gScanned;
static NSInteger gHookedClasses;
static NSInteger gHits;
static NSMutableArray<NSString *> *gSamples;

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

// Cheap: exact set membership, then two substring checks only if needed.
static BOOL WPIsLaneKey(NSString *s) {
    if ([WPLaneKeys() containsObject:s]) return YES;
    return [s containsString:@"lane_guidance"] || [s containsString:@"continue_straight"];
}

typedef BOOL (*WPBoolIMP)(id, SEL, id);

static BOOL WPHookBoolForKey(Class cls) {
    SEL sel = @selector(boolForKey:);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    const char *enc = method_getTypeEncoding(m);
    if (!enc || (enc[0] != 'c' && enc[0] != 'B')) return NO; // BOOL return only

    __block WPBoolIMP orig = (WPBoolIMP)method_getImplementation(m);
    IMP r = imp_implementationWithBlock(^BOOL(id self, id key) {
        if ([key isKindOfClass:NSString.class] && WPIsLaneKey(key)) {
            @synchronized (WPLaneGuidance.class) {
                gHits++;
                if (gSamples.count < 40 && ![gSamples containsObject:key]) [gSamples addObject:key];
            }
            return YES; // force lane-guidance flags on
        }
        return orig(self, sel, key);
    });
    method_setImplementation(m, r);
    return YES;
}

@implementation WPLaneGuidance

+ (void)installIfEnabled {
    if (gInstalled) return;
    if (!WPPrefs.shared.laneGuidance) return;
    if (!gSamples) gSamples = [NSMutableArray array];

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSInteger hooked = 0;
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        NSString *n = @(name);
        if (![n containsString:@"ConfigService"] && ![n containsString:@"ConfigFeatureManager"]) continue;
        if (WPHookBoolForKey(classes[i])) hooked++;
    }
    free(classes);
    gHookedClasses = hooked;
    gScanned = YES;
    if (hooked > 0) gInstalled = YES;
    NSLog(@"[WazePatch] lane guidance, hooked config classes: %ld (installed=%d)", (long)hooked, gInstalled);
}

+ (void)installWithRetries {
    [self installIfEnabled];
    if (gInstalled || !WPPrefs.shared.laneGuidance) return;
    static int attempts = 0;
    if (attempts++ >= 10) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self installWithRetries];
    });
}

+ (NSString *)statusSummary {
    if (!WPPrefs.shared.laneGuidance) return @"Oprit";
    if (!gScanned) return @"Repornește Waze";
    return [NSString stringWithFormat:@"%ld clase · %ld citiri", (long)gHookedClasses, (long)gHits];
}

+ (NSArray<NSString *> *)samples {
    @synchronized (WPLaneGuidance.class) {
        return [gSamples copy] ?: @[];
    }
}

@end

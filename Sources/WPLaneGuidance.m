#import "WPLaneGuidance.h"
#import "WPPrefs.h"
#import <objc/runtime.h>
#import <objc/message.h>

// Diagnostics shown in-app so the user doesn't need Console.
static BOOL gInstalled;
static NSInteger gHookedClasses;
static NSInteger gHits;                         // lane-guidance reads seen
static NSMutableArray<NSString *> *gSamples;    // "selector | keyClass | keyPreview"

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

static BOOL WPTextHasLane(NSString *s) {
    if (![s isKindOfClass:NSString.class]) return NO;
    return [s containsString:@"lane_guidance"] || [s containsString:@"continue_straight"]
        || [s containsString:@"LANE_GUIDANCE"] || [s containsString:@"CONTINUE_STRAIGHT"];
}

// A short, cheap-ish description of a config key, string or object.
static NSString *WPKeyPreview(id key) {
    if ([key isKindOfClass:NSString.class]) return key;
    NSString *cls = NSStringFromClass([key class]) ?: @"?";
    for (NSString *g in @[@"name", @"key", @"identifier", @"stringValue"]) {
        SEL s = NSSelectorFromString(g);
        if ([key respondsToSelector:s]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(key, s);
            if ([v isKindOfClass:NSString.class] && [v length]) return [NSString stringWithFormat:@"%@(%@)", cls, v];
        }
    }
    return cls;
}

// Returns YES if this key is a lane-guidance key; records a sample for the UI.
static BOOL WPRecordAndMatch(SEL sel, id key) {
    BOOL stringMatch = [key isKindOfClass:NSString.class]
        && ([WPLaneKeys() containsObject:key] || WPTextHasLane(key));
    NSString *preview = nil;
    BOOL laneRelated = stringMatch;
    if (!laneRelated) {
        preview = WPKeyPreview(key);
        laneRelated = WPTextHasLane(preview);
    }
    if (!laneRelated) return stringMatch;

    @synchronized (WPLaneGuidance.class) {
        gHits++;
        if (gSamples.count < 60) {
            if (!preview) preview = WPKeyPreview(key);
            NSString *line = [NSString stringWithFormat:@"%@ | %@ | %@",
                NSStringFromSelector(sel), NSStringFromClass([key class]) ?: @"?", preview];
            if (![gSamples containsObject:line]) [gSamples addObject:line];
        }
    }
    return stringMatch;
}

typedef BOOL (*WPBoolIMP)(id, SEL, id);
typedef id   (*WPIdIMP)(id, SEL, id);

// Swizzles a one-object-argument accessor to observe lane-guidance reads; for
// BOOL accessors it also forces YES on a string-key match (the actual override).
static BOOL WPSwizzle1Obj(Class cls, SEL sel, BOOL forceBoolOnMatch) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    const char *enc = method_getTypeEncoding(m);
    if (!enc) return NO;
    char ret = enc[0];

    if (ret == 'c' || ret == 'B') {
        __block WPBoolIMP orig = (WPBoolIMP)method_getImplementation(m);
        IMP r = imp_implementationWithBlock(^BOOL(id self, id key) {
            BOOL match = WPRecordAndMatch(sel, key);
            if (match && forceBoolOnMatch) return YES;
            return orig(self, sel, key);
        });
        method_setImplementation(m, r);
        return YES;
    } else if (ret == '@') {
        __block WPIdIMP orig = (WPIdIMP)method_getImplementation(m);
        IMP r = imp_implementationWithBlock(^id(id self, id key) {
            WPRecordAndMatch(sel, key);
            return orig(self, sel, key);
        });
        method_setImplementation(m, r);
        return YES;
    }
    return NO;
}

@implementation WPLaneGuidance

+ (void)installIfEnabled {
    if (gInstalled) return;
    if (!WPPrefs.shared.laneGuidance) return;
    gSamples = [NSMutableArray array];

    SEL accessors[] = {
        @selector(boolForKey:),
        @selector(configValueForKey:),
        @selector(cachedValueForConfigFlag:),
        @selector(configValueFor:),
    };

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSInteger hooked = 0;
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        NSString *n = @(name);
        if (![n containsString:@"ConfigService"] && ![n containsString:@"ConfigFeatureManager"]) continue;
        BOOL any = NO;
        for (size_t k = 0; k < sizeof(accessors) / sizeof(accessors[0]); k++) {
            BOOL forceBool = (accessors[k] == @selector(boolForKey:));
            if (WPSwizzle1Obj(classes[i], accessors[k], forceBool)) any = YES;
        }
        if (any) hooked++;
    }
    free(classes);
    gInstalled = YES;
    gHookedClasses = hooked;
    NSLog(@"[WazePatch] lane guidance diagnostic installed, hooked config classes: %ld", (long)hooked);
}

+ (NSString *)statusSummary {
    if (!WPPrefs.shared.laneGuidance) return @"Oprit";
    if (!gInstalled) return @"Repornește Waze";
    return [NSString stringWithFormat:@"%ld clase · %ld citiri", (long)gHookedClasses, (long)gHits];
}

+ (NSArray<NSString *> *)samples {
    @synchronized (WPLaneGuidance.class) {
        return [gSamples copy] ?: @[];
    }
}

@end

#import <Foundation/Foundation.h>

// Forces Waze's built-in lane guidance config flags on, for users who want lane
// guidance shown. Mirrors the Android community patch, adapted to the iOS config
// keys found in the 5.26 binary. Opt-in; safe no-op if the flags aren't read as
// string-keyed booleans.
@interface WPLaneGuidance : NSObject
+ (void)installIfEnabled;
@end

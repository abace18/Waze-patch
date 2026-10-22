#import <Foundation/Foundation.h>

// Posted on the main thread after every location update.
FOUNDATION_EXPORT NSString *const WPSpeedDidChangeNotification;

// Shared GPS speed source. Location updates run only while at least one
// consumer (a speedometer, the background keep-alive) has asked for them.
@interface WPSpeed : NSObject
+ (instancetype)shared;

// Speed in the unit chosen in the settings, -1 when unknown.
@property (nonatomic, readonly) NSInteger displaySpeed;
// YES while above the warning threshold.
@property (nonatomic, readonly) BOOL overLimit;

- (void)addConsumer:(NSString *)name;
- (void)removeConsumer:(NSString *)name;
@end

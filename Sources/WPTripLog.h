#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

// A single recorded trip.
@interface WPTrip : NSObject
@property (nonatomic, strong) NSDate *start;
@property (nonatomic, strong) NSDate *end;
@property (nonatomic) double distance;      // metres
@property (nonatomic) double maxSpeed;      // m/s
@property (nonatomic, strong) NSArray *points; // [{lat,lon,t,spd}] as NSDictionary

@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) double avgSpeed; // m/s
- (NSString *)gpx;
@end

// Local trip recorder. Runs only when enabled in settings; stores completed
// trips in the app container. Everything stays on device.
@interface WPTripLog : NSObject
+ (instancetype)shared;

@property (nonatomic, readonly) BOOL recording;
@property (nonatomic, readonly) NSArray<WPTrip *> *trips; // newest first

- (void)applyPrefs;        // start/stop according to the setting
- (void)deleteTripAtIndex:(NSInteger)index;
- (void)clearAll;
@end

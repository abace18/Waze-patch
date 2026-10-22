#import "WPTripLog.h"
#import "WPPrefs.h"
#import "WPSpeed.h"

static NSString *WPTripsFile(void) {
    NSString *dir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"wazepatch_trips.json"];
}

@implementation WPTrip

- (NSTimeInterval)duration {
    return [self.end timeIntervalSinceDate:self.start];
}

- (double)avgSpeed {
    NSTimeInterval d = self.duration;
    return d > 0 ? self.distance / d : 0;
}

- (NSDictionary *)dictionary {
    return @{
        @"start": @(self.start.timeIntervalSince1970),
        @"end": @(self.end.timeIntervalSince1970),
        @"distance": @(self.distance),
        @"maxSpeed": @(self.maxSpeed),
        @"points": self.points ?: @[],
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)d {
    WPTrip *t = [WPTrip new];
    t.start = [NSDate dateWithTimeIntervalSince1970:[d[@"start"] doubleValue]];
    t.end = [NSDate dateWithTimeIntervalSince1970:[d[@"end"] doubleValue]];
    t.distance = [d[@"distance"] doubleValue];
    t.maxSpeed = [d[@"maxSpeed"] doubleValue];
    t.points = [d[@"points"] isKindOfClass:NSArray.class] ? d[@"points"] : @[];
    return t;
}

- (NSString *)gpx {
    NSDateFormatter *iso = [NSDateFormatter new];
    iso.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    iso.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    iso.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];

    NSMutableString *s = [NSMutableString string];
    [s appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
    [s appendString:@"<gpx version=\"1.1\" creator=\"WazePatch\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"];
    [s appendFormat:@"<trk><name>%@</name><trkseg>\n", [iso stringFromDate:self.start]];
    for (NSDictionary *p in self.points) {
        [s appendFormat:@"<trkpt lat=\"%.6f\" lon=\"%.6f\"><time>%@</time></trkpt>\n",
            [p[@"lat"] doubleValue], [p[@"lon"] doubleValue],
            [iso stringFromDate:[NSDate dateWithTimeIntervalSince1970:[p[@"t"] doubleValue]]]];
    }
    [s appendString:@"</trkseg></trk>\n</gpx>\n"];
    return s;
}

@end

@implementation WPTripLog {
    NSMutableArray<WPTrip *> *_trips;
    // Current trip being built.
    NSMutableArray *_points;
    NSDate *_curStart;
    NSDate *_curEnd;
    double _curDistance;
    double _curMaxSpeed;
    CLLocation *_lastPoint;
    NSDate *_lastMovement;
}

+ (instancetype)shared {
    static WPTripLog *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [WPTripLog new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        [self load];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(speedChanged)
                                                     name:WPSpeedDidChangeNotification object:nil];
    }
    return self;
}

- (NSArray<WPTrip *> *)trips {
    return [_trips copy];
}

#pragma mark - Persistence

- (void)load {
    _trips = [NSMutableArray array];
    NSData *data = [NSData dataWithContentsOfFile:WPTripsFile()];
    NSArray *raw = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if ([raw isKindOfClass:NSArray.class]) {
        for (NSDictionary *d in raw) {
            if ([d isKindOfClass:NSDictionary.class]) [_trips addObject:[WPTrip fromDictionary:d]];
        }
    }
}

- (void)save {
    NSMutableArray *raw = [NSMutableArray array];
    for (WPTrip *t in _trips) [raw addObject:[t dictionary]];
    NSData *data = [NSJSONSerialization dataWithJSONObject:raw options:0 error:nil];
    [data writeToFile:WPTripsFile() atomically:YES];
}

#pragma mark - Recording

- (void)applyPrefs {
    BOOL want = WPPrefs.shared.tripLog;
    if (want && !_recording) {
        _recording = YES;
        [WPSpeed.shared addConsumer:@"triplog"];
    } else if (!want && _recording) {
        [self finalizeTrip];
        _recording = NO;
        [WPSpeed.shared removeConsumer:@"triplog"];
    }
}

- (void)speedChanged {
    if (!_recording) return;
    CLLocation *loc = WPSpeed.shared.lastLocation;
    if (!loc || loc.horizontalAccuracy < 0 || loc.horizontalAccuracy > 50) return;

    NSDate *now = loc.timestamp ?: [NSDate date];
    double speed = loc.speed > 0 ? loc.speed : 0;

    // A gap in movement ends the current trip.
    if (_curStart && _lastMovement && [now timeIntervalSinceDate:_lastMovement] > 180) {
        [self finalizeTrip];
    }

    if (!_curStart) {
        if (speed < 2) return; // wait until actually moving to start a trip
        _curStart = now;
        _points = [NSMutableArray array];
        _curDistance = 0;
        _curMaxSpeed = 0;
        _lastPoint = nil;
    }

    if (_lastPoint) {
        CLLocationDistance d = [loc distanceFromLocation:_lastPoint];
        if (d < 5) { _curEnd = now; return; } // ignore jitter, keep end fresh
        _curDistance += d;
    }
    _lastPoint = loc;
    _curEnd = now;
    if (speed > 1) _lastMovement = now;
    _curMaxSpeed = MAX(_curMaxSpeed, speed);

    // Cap stored points so the file stays small (~1 point / 5m above).
    if (_points.count < 20000) {
        [_points addObject:@{
            @"lat": @(loc.coordinate.latitude),
            @"lon": @(loc.coordinate.longitude),
            @"t": @(now.timeIntervalSince1970),
            @"spd": @(speed),
        }];
    }
}

- (void)finalizeTrip {
    if (!_curStart || _curDistance < 200) { // discard trivial trips
        [self resetCurrent];
        return;
    }
    WPTrip *trip = [WPTrip new];
    trip.start = _curStart;
    trip.end = _curEnd ?: _curStart;
    trip.distance = _curDistance;
    trip.maxSpeed = _curMaxSpeed;
    trip.points = [_points copy];
    [_trips insertObject:trip atIndex:0];
    [self save];
    [self resetCurrent];
}

- (void)resetCurrent {
    _curStart = nil;
    _curEnd = nil;
    _points = nil;
    _lastPoint = nil;
    _lastMovement = nil;
    _curDistance = 0;
    _curMaxSpeed = 0;
}

#pragma mark - Editing

- (void)deleteTripAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)_trips.count) return;
    [_trips removeObjectAtIndex:index];
    [self save];
}

- (void)clearAll {
    [_trips removeAllObjects];
    [self save];
}

@end

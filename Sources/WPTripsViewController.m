#import "WPTripsViewController.h"
#import "WPPrefs.h"
#import "WPTripLog.h"

@implementation WPTripsViewController {
    NSArray<WPTrip *> *_trips;
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Călătorii";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                                           target:self action:@selector(clear)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _trips = WPTripLog.shared.trips;
    [self.tableView reloadData];
}

- (void)clear {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ștergi toate călătoriile?"
                                                              message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Anulează" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Șterge" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        [WPTripLog.shared clearAll];
        self->_trips = WPTripLog.shared.trips;
        [self.tableView reloadData];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSString *)formatDistance:(double)metres {
    if (WPPrefs.shared.speedUnit == WPSpeedUnitMph) return [NSString stringWithFormat:@"%.1f mi", metres / 1609.344];
    return [NSString stringWithFormat:@"%.1f km", metres / 1000.0];
}

- (NSString *)formatSpeed:(double)mps {
    BOOL mph = WPPrefs.shared.speedUnit == WPSpeedUnitMph;
    return [NSString stringWithFormat:@"%.0f %@", mps * (mph ? 2.23694 : 3.6), mph ? @"mph" : @"km/h"];
}

- (NSString *)formatDuration:(NSTimeInterval)s {
    NSInteger m = (NSInteger)(s / 60);
    return m >= 60 ? [NSString stringWithFormat:@"%ldh %ldm", (long)(m / 60), (long)(m % 60)]
                   : [NSString stringWithFormat:@"%ldm", (long)m];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _trips.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_trips.count == 0) return @"Nicio călătorie încă";
    return [NSString stringWithFormat:@"%lu călătorii", (unsigned long)_trips.count];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Atinge o călătorie ca să exporți GPX. Tras la stânga pentru ștergere.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WPTrip *t = _trips[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];

    NSDateFormatter *df = [NSDateFormatter new];
    df.dateStyle = NSDateFormatterMediumStyle;
    df.timeStyle = NSDateFormatterShortStyle;
    cell.textLabel.text = [df stringFromDate:t.start];
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · medie %@ · max %@",
        [self formatDistance:t.distance], [self formatDuration:t.duration],
        [self formatSpeed:t.avgSpeed], [self formatSpeed:t.maxSpeed]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    WPTrip *t = _trips[indexPath.row];

    NSString *name = [NSString stringWithFormat:@"waze-trip-%.0f.gpx", t.start.timeIntervalSince1970];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[t gpx] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                      applicationActivities:nil];
    share.popoverPresentationController.sourceView = [tableView cellForRowAtIndexPath:indexPath];
    [self presentViewController:share animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    [WPTripLog.shared deleteTripAtIndex:indexPath.row];
    _trips = WPTripLog.shared.trips;
    [tableView reloadData];
}

@end

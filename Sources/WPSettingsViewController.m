#import "WPSettingsViewController.h"
#import "WPEnvironment.h"
#import "WPPrefs.h"

typedef NS_ENUM(NSInteger, WPRowType) {
    WPRowInfo,
    WPRowSwitch,
    WPRowSegment,
    WPRowStepper,
};

@interface WPRow : NSObject
@property (nonatomic) WPRowType type;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *detail;        // info rows
@property (nonatomic, copy) NSArray<NSString *> *segments;
@property (nonatomic) NSInteger min, max, step;      // stepper rows
@property (nonatomic, copy) NSString *(^format)(NSInteger value);
@end

@implementation WPRow
@end

@interface WPSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) NSArray<WPRow *> *rows;
@end

@implementation WPSection
@end

static WPRow *WPInfoRow(NSString *title, NSString *detail) {
    WPRow *row = [WPRow new];
    row.type = WPRowInfo;
    row.title = title;
    row.detail = detail;
    return row;
}

static WPRow *WPSwitchRow(NSString *title, NSString *key) {
    WPRow *row = [WPRow new];
    row.type = WPRowSwitch;
    row.title = title;
    row.key = key;
    return row;
}

static WPRow *WPSegmentRow(NSString *title, NSString *key, NSArray<NSString *> *segments) {
    WPRow *row = [WPRow new];
    row.type = WPRowSegment;
    row.title = title;
    row.key = key;
    row.segments = segments;
    return row;
}

static WPRow *WPStepperRow(NSString *title, NSString *key, NSInteger min, NSInteger max, NSInteger step, NSString *(^format)(NSInteger)) {
    WPRow *row = [WPRow new];
    row.type = WPRowStepper;
    row.title = title;
    row.key = key;
    row.min = min;
    row.max = max;
    row.step = step;
    row.format = format;
    return row;
}

static WPSection *WPMakeSection(NSString *title, NSString *footer, NSArray<WPRow *> *rows) {
    WPSection *section = [WPSection new];
    section.title = title;
    section.footer = footer;
    section.rows = rows;
    return section;
}

@implementation WPSettingsViewController {
    NSArray<WPSection *> *_sections;
}

+ (void)presentInWindow:(UIWindow *)window {
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;
    if ([top isKindOfClass:UINavigationController.class]
        && [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:self]) {
        return; // already open
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[self new]];
    [top presentViewController:nav animated:YES completion:nil];
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"WazePatch";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(close)];

    NSArray<NSString *> *corners = @[@"↖", @"↗", @"↙", @"↘"];
    NSString *(^speed)(NSInteger) = ^NSString *(NSInteger value) {
        if (value == 0) return @"Oprit";
        return [NSString stringWithFormat:@"%ld %@", (long)value, WPPrefs.shared.speedUnit == WPSpeedUnitMph ? @"mph" : @"km/h"];
    };
    NSString *(^percent)(NSInteger) = ^NSString *(NSInteger value) {
        return [NSString stringWithFormat:@"%ld%%", (long)value];
    };

    _sections = @[
        WPMakeSection(@"Status", @"Setările se deschid cu o apăsare lungă cu 3 degete pe ecran sau prin scuturarea telefonului.", @[
            WPInfoRow(@"WazePatch", WP_VERSION),
            WPInfoRow(@"Waze", WPWazeVersion()),
            WPInfoRow(@"Instalare", WPInstallModeName(WPCurrentInstallMode())),
        ]),
        WPMakeSection(@"Vitezometru", nil, @[
            WPSwitchRow(@"Pe telefon", WPKeyPhoneSpeedometer),
            WPSegmentRow(@"Poziție telefon", WPKeyPhoneCorner, corners),
            WPSwitchRow(@"Pe CarPlay", WPKeyCarSpeedometer),
            WPSegmentRow(@"Poziție CarPlay", WPKeyCarCorner, corners),
            WPSwitchRow(@"Buton pe harta CarPlay", WPKeyCarToggleButton),
            WPSegmentRow(@"Unitate", WPKeySpeedUnit, @[@"km/h", @"mph"]),
            WPStepperRow(@"Mărime", WPKeySpeedScale, 50, 200, 10, percent),
        ]),
        WPMakeSection(@"Avertizare viteză", @"Vitezometrul devine roșu peste prag. Alerta se repetă doar după ce cobori sub prag.", @[
            WPStepperRow(@"Prag", WPKeySpeedWarn, 0, 250, 5, speed),
            WPSwitchRow(@"Vibrație", WPKeyWarnVibrate),
            WPSwitchRow(@"Sunet", WPKeyWarnSound),
        ]),
        WPMakeSection(@"Dimmer OLED", @"Întunecă ecranul peste harta Waze, noaptea. Atingerile trec prin el, nemodificat.", @[
            WPSwitchRow(@"Dimmer", WPKeyDimmer),
            WPStepperRow(@"Intensitate", WPKeyDimmerIntensity, 0, 90, 5, percent),
        ]),
        WPMakeSection(@"Sistem", @"„Activ în fundal” consumă mai multă baterie. „120 Hz” se aplică după repornirea Waze.", @[
            WPSwitchRow(@"Ecran mereu aprins", WPKeyKeepAwake),
            WPSwitchRow(@"Activ în fundal", WPKeyBackgroundAlive),
            WPSwitchRow(@"120 Hz pe ecrane ProMotion", WPKeyHighRefresh),
            WPSwitchRow(@"Mesaj la pornire", WPKeyLaunchToast),
        ]),
    ];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (WPRow *)rowAtIndexPath:(NSIndexPath *)indexPath {
    return _sections[indexPath.section].rows[indexPath.row];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return _sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WPRow *row = [self rowAtIndexPath:indexPath];
    WPPrefs *prefs = WPPrefs.shared;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = row.title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    // Controls find their row again through the tag.
    NSInteger tag = indexPath.section * 1000 + indexPath.row;

    switch (row.type) {
        case WPRowInfo:
            cell.detailTextLabel.text = row.detail;
            break;
        case WPRowSwitch: {
            UISwitch *toggle = [UISwitch new];
            toggle.on = [prefs boolForKey:row.key];
            toggle.tag = tag;
            [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = toggle;
            break;
        }
        case WPRowSegment: {
            UISegmentedControl *segments = [[UISegmentedControl alloc] initWithItems:row.segments];
            segments.selectedSegmentIndex = [prefs integerForKey:row.key];
            segments.tag = tag;
            [segments addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
            [segments sizeToFit];
            cell.accessoryView = segments;
            break;
        }
        case WPRowStepper: {
            NSInteger value = [prefs integerForKey:row.key];
            UIStepper *stepper = [UIStepper new];
            stepper.minimumValue = row.min;
            stepper.maximumValue = row.max;
            stepper.stepValue = row.step;
            stepper.value = value;
            stepper.tag = tag;
            [stepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = stepper;
            cell.detailTextLabel.text = row.format(value);
            break;
        }
    }
    return cell;
}

- (NSIndexPath *)indexPathForTag:(NSInteger)tag {
    return [NSIndexPath indexPathForRow:tag % 1000 inSection:tag / 1000];
}

- (void)switchChanged:(UISwitch *)sender {
    WPRow *row = [self rowAtIndexPath:[self indexPathForTag:sender.tag]];
    [WPPrefs.shared setObject:@(sender.on) forKey:row.key];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    WPRow *row = [self rowAtIndexPath:[self indexPathForTag:sender.tag]];
    [WPPrefs.shared setObject:@(sender.selectedSegmentIndex) forKey:row.key];
    // The threshold label shows the unit.
    if ([row.key isEqualToString:WPKeySpeedUnit]) [self.tableView reloadData];
}

- (void)stepperChanged:(UIStepper *)sender {
    NSIndexPath *indexPath = [self indexPathForTag:sender.tag];
    WPRow *row = [self rowAtIndexPath:indexPath];
    NSInteger value = (NSInteger)sender.value;
    [WPPrefs.shared setObject:@(value) forKey:row.key];
    [self.tableView cellForRowAtIndexPath:indexPath].detailTextLabel.text = row.format(value);
}

@end

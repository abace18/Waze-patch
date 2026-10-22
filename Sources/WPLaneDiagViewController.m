#import "WPLaneDiagViewController.h"
#import "WPLaneGuidance.h"

@implementation WPLaneDiagViewController {
    NSArray<NSString *> *_samples;
}

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnostic benzi";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                           target:self action:@selector(reload)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)reload {
    _samples = [WPLaneGuidance samples];
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX(1, (NSInteger)_samples.count);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [WPLaneGuidance statusSummary];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Pornește o navigație, apoi apasă reîmprospătare. Fiecare rând: metodă | tipul cheii | cheia.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (_samples.count == 0) {
        cell.textLabel.text = @"Nicio citire de lane guidance încă.";
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
    } else {
        cell.textLabel.text = _samples[indexPath.row];
    }
    return cell;
}

@end

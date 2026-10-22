#import <Preferences/PSListController.h>

@interface WPRootListController : PSListController
@end

@implementation WPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end

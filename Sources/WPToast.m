#import "WPToast.h"

@implementation WPToast

+ (void)showText:(NSString *)text inWindow:(UIWindow *)window {
    if (!window) return;

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;

    UIView *pill = [UIView new];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    pill.userInteractionEnabled = NO;
    pill.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    pill.layer.cornerRadius = 16;
    pill.alpha = 0;
    [pill addSubview:label];
    [window addSubview:pill];

    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:pill.topAnchor constant:8],
        [label.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-8],
        [label.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:16],
        [label.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-16],
        [pill.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
        [pill.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:8],
    ]];

    [UIView animateWithDuration:0.25 animations:^{
        pill.alpha = 1;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4 delay:2.5 options:0 animations:^{
            pill.alpha = 0;
        } completion:^(BOOL done) {
            [pill removeFromSuperview];
        }];
    }];
}

@end

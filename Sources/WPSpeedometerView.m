#import "WPSpeedometerView.h"
#import "WPPrefs.h"
#import "WPSpeed.h"

@implementation WPSpeedometerView {
    UILabel *_speedLabel;
    UILabel *_unitLabel;
    NSLayoutConstraint *_width;
    NSLayoutConstraint *_height;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.userInteractionEnabled = NO;
        self.layer.masksToBounds = YES;

        _speedLabel = [UILabel new];
        _speedLabel.textColor = UIColor.whiteColor;
        _speedLabel.textAlignment = NSTextAlignmentCenter;
        _speedLabel.adjustsFontSizeToFitWidth = YES;
        _speedLabel.minimumScaleFactor = 0.5;

        _unitLabel = [UILabel new];
        _unitLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
        _unitLabel.textAlignment = NSTextAlignmentCenter;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_speedLabel, _unitLabel]];
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.axis = UILayoutConstraintAxisVertical;
        stack.alignment = UIStackViewAlignmentCenter;
        [self addSubview:stack];

        _width = [self.widthAnchor constraintEqualToConstant:78];
        _height = [self.heightAnchor constraintEqualToConstant:60];
        [NSLayoutConstraint activateConstraints:@[
            _width,
            _height,
            [stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:4],
        ]];
        [self applyScale:1];
    }
    return self;
}

- (void)applyScale:(CGFloat)scale {
    _speedLabel.font = [UIFont monospacedDigitSystemFontOfSize:30 * scale weight:UIFontWeightBold];
    _unitLabel.font = [UIFont systemFontOfSize:11 * scale weight:UIFontWeightSemibold];
    self.layer.cornerRadius = 14 * scale;
    _width.constant = 78 * scale;
    _height.constant = 60 * scale;
}

- (void)refresh {
    WPSpeed *speed = WPSpeed.shared;
    _unitLabel.text = WPPrefs.shared.speedUnit == WPSpeedUnitMph ? @"mph" : @"km/h";
    NSInteger shown = speed.displaySpeed;
    _speedLabel.text = shown < 0 ? @"--" : [NSString stringWithFormat:@"%ld", (long)shown];
    self.backgroundColor = speed.overLimit
        ? [UIColor colorWithRed:0.85 green:0.1 blue:0.1 alpha:0.9]
        : [UIColor colorWithWhite:0 alpha:0.7];
}

@end

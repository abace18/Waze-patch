#import <UIKit/UIKit.h>

// The speed badge; it sizes itself, the owner only positions it.
@interface WPSpeedometerView : UIView
- (void)applyScale:(CGFloat)scale;
- (void)refresh;
@end

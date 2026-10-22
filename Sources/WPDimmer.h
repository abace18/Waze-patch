#import <UIKit/UIKit.h>

// A dark overlay drawn above Waze's map to dim the screen at night (OLED-style).
// Our own view — we never touch Waze's own theme. Non-interactive: taps pass
// through to the map underneath.
@interface WPDimmer : NSObject
+ (instancetype)shared;

- (void)setPhoneWindow:(UIWindow *)window;
- (void)setCarWindow:(UIWindow *)window;
- (void)carWindowGone;
- (void)windowDidLayout:(UIWindow *)window;
- (void)refresh;
@end

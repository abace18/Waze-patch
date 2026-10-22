#import <UIKit/UIKit.h>

// Speed overlay drawn on top of Waze's CarPlay map window.
@interface WPSpeedometer : NSObject
+ (instancetype)shared;

@property (nonatomic, weak, readonly) UIWindow *window;
// Toggled from the CarPlay map button; not persisted.
@property (nonatomic) BOOL userHidden;

- (void)attachToWindow:(UIWindow *)window;
- (void)windowDidLayout:(UIWindow *)window;
- (void)detach;
@end

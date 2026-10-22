#import <UIKit/UIKit.h>

// Places speedometers on the phone map and on the CarPlay map window.
@interface WPOverlay : NSObject
+ (instancetype)shared;

// Toggled from the CarPlay map button; not persisted.
@property (nonatomic) BOOL carHidden;

- (void)setPhoneWindow:(UIWindow *)window;
- (void)setCarWindow:(UIWindow *)window;
- (void)carWindowGone;
// Called on every window layout pass; keeps the badges on top.
- (void)windowDidLayout:(UIWindow *)window;
- (void)refresh;
@end

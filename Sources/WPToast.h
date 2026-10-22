#import <UIKit/UIKit.h>

@interface WPToast : NSObject
// Shows a short pill at the top of the window, then fades it out.
+ (void)showText:(NSString *)text inWindow:(UIWindow *)window;
@end

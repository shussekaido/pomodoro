#import <Foundation/Foundation.h>

@interface NotificationService : NSObject <NSUserNotificationCenterDelegate>

+ (instancetype)shared;

- (void)requestAuthorizationIfNeeded;

- (void)postWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier;

@end

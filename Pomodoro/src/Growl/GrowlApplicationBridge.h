// Minimal Growl shim for modern macOS where Growl is unavailable
#import <Cocoa/Cocoa.h>

@protocol GrowlApplicationBridgeDelegate <NSObject>
@optional
- (NSDictionary *)registrationDictionaryForGrowl;
@end

@interface GrowlApplicationBridge : NSObject
+ (void)setGrowlDelegate:(id<GrowlApplicationBridgeDelegate>)delegate;
+ (BOOL)isGrowlInstalled;
+ (BOOL)isGrowlRunning;
+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)name
                iconData:(NSData *)iconData
                priority:(NSInteger)priority
                isSticky:(BOOL)isSticky
            clickContext:(id)clickContext;
@end


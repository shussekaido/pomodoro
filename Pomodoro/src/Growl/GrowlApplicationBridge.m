#import "GrowlApplicationBridge.h"

static id<GrowlApplicationBridgeDelegate> sDelegate = nil;

@implementation GrowlApplicationBridge

+ (void)setGrowlDelegate:(id<GrowlApplicationBridgeDelegate>)delegate {
    sDelegate = delegate;
}

+ (BOOL)isGrowlInstalled {
    return NO;
}

+ (BOOL)isGrowlRunning {
    return NO;
}

+ (void)notifyWithTitle:(NSString *)title
            description:(NSString *)description
       notificationName:(NSString *)name
                iconData:(NSData *)iconData
                priority:(NSInteger)priority
                isSticky:(BOOL)isSticky
            clickContext:(id)clickContext {
    // No-op shim. In the future, bridge to Notification Center.
    (void)title; (void)description; (void)name; (void)iconData; (void)priority; (void)isSticky; (void)clickContext;
    (void)sDelegate;
}

@end


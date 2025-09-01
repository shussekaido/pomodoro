#import "NotificationService.h"
#import <objc/runtime.h>
#import <objc/message.h>

@interface NotificationService ()
@property (nonatomic, assign) BOOL authorizationRequested;
@end

@implementation NotificationService

+ (instancetype)shared {
    static NotificationService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        // Legacy center delegate so notifications show when frontmost.
        @try { [NSUserNotificationCenter defaultUserNotificationCenter].delegate = (id)self; } @catch (__unused id e) {}
        // Try to become UNUserNotificationCenter delegate so alerts show while app is frontmost.
        Class UNCenter = NSClassFromString(@"UNUserNotificationCenter");
        if (UNCenter) {
            id center = ((id (*)(id, SEL))objc_msgSend)(UNCenter, sel_registerName("currentNotificationCenter"));
            SEL setDel = sel_registerName("setDelegate:");
            if ([center respondsToSelector:setDel]) {
                ((void (*)(id, SEL, id))objc_msgSend)(center, setDel, self);
            }
        }
    }
    return self;
}

- (void)requestAuthorizationIfNeeded {
    Class UNCenter = NSClassFromString(@"UNUserNotificationCenter");
    if (!UNCenter) return; // Older macOS
    if (self.authorizationRequested) return;
    self.authorizationRequested = YES;
    // (Removed debug file logging)

    id center = ((id (*)(id, SEL))objc_msgSend)(UNCenter, sel_registerName("currentNotificationCenter"));
    // options = alert|sound|badge => 0x7
    NSUInteger options = (1<<0) | (1<<1) | (1<<2);
    void (^completion)(BOOL, NSError *) = ^(BOOL granted, NSError *error){ (void)granted; (void)error; };
    SEL sel = sel_registerName("requestAuthorizationWithOptions:completionHandler:");
    if ([center respondsToSelector:sel]) {
        ((void (*)(id, SEL, NSUInteger, id))objc_msgSend)(center, sel, options, completion);
    }
}

- (void)postWithTitle:(NSString *)title body:(NSString *)body identifier:(NSString *)identifier {
    Class UNCenter = NSClassFromString(@"UNUserNotificationCenter");
    Class UNContentClass = NSClassFromString(@"UNMutableNotificationContent");
    Class UNRequestClass = NSClassFromString(@"UNNotificationRequest");
    if (!UNCenter || !UNContentClass || !UNRequestClass) return;

    [self requestAuthorizationIfNeeded];
    // (Removed debug file logging)

    id center = ((id (*)(id, SEL))objc_msgSend)(UNCenter, sel_registerName("currentNotificationCenter"));

    // Fetch settings and proceed only if authorized/provisional
    SEL getSettingsSel = sel_registerName("getNotificationSettingsWithCompletionHandler:");
    if ([center respondsToSelector:getSettingsSel]) {
        void (^settingsBlock)(id) = ^(id settings){
            // (Removed debug file logging)
            // authorizationStatus property returns integer; 2=Denied, 3=Authorized, 4=Provisional (on modern SDKs)
            NSInteger status = 0;
            if ([settings respondsToSelector:@selector(authorizationStatus)]) {
                status = ((NSInteger (*)(id, SEL))objc_msgSend)(settings, @selector(authorizationStatus));
            }
            // Allow: Authorized (2), Provisional (3), Ephemeral (4). If NotDetermined (0), still try to post (system may prompt); if Denied (1), bail.
            if (status == 1) return;

            id content = [[UNContentClass alloc] init];
            if ([content respondsToSelector:@selector(setTitle:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(content, @selector(setTitle:), title ?: @"");
            }
            if ([content respondsToSelector:@selector(setBody:)]) {
                ((void (*)(id, SEL, id))objc_msgSend)(content, @selector(setBody:), body ?: @"");
            }
            // setSound: defaultSound
            Class UNSound = NSClassFromString(@"UNNotificationSound");
            if (UNSound && [UNSound respondsToSelector:@selector(defaultSound)]) {
                id defSound = ((id (*)(id, SEL))objc_msgSend)(UNSound, @selector(defaultSound));
                if ([content respondsToSelector:@selector(setSound:)]) {
                    ((void (*)(id, SEL, id))objc_msgSend)(content, @selector(setSound:), defSound);
                }
            }

            NSString *reqID = identifier ?: [[NSUUID UUID] UUIDString];
            id request = ((id (*)(id, SEL, id, id, id))objc_msgSend)(UNRequestClass,
                                                                     sel_registerName("requestWithIdentifier:content:trigger:"),
                                                                     reqID, content, nil);
            SEL addSel = sel_registerName("addNotificationRequest:withCompletionHandler:");
            if ([center respondsToSelector:addSel]) {
                ((void (*)(id, SEL, id, id))objc_msgSend)(center, addSel, request, (id)^(NSError *error){ (void)error; });
            }
            // Fallback also post via NSUserNotificationCenter (deprecated but widely supported)
            @try {
                NSUserNotification *legacy = [[NSUserNotification alloc] init];
                legacy.title = title ?: @"";
                legacy.informativeText = body ?: @"";
                legacy.soundName = NSUserNotificationDefaultSoundName;
                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:legacy];
            } @catch (__unused id e) {}
        };
        ((void (*)(id, SEL, id))objc_msgSend)(center, getSettingsSel, settingsBlock);
    }
}

// Present alerts while app is in foreground by calling completion handler with alert+sound options.
- (void)userNotificationCenter:(id)center willPresentNotification:(id)notification withCompletionHandler:(void (^)(NSUInteger options))completionHandler {
    // (Removed debug file logging)
    if (completionHandler) {
        // UNNotificationPresentationOptionSound (1) | UNNotificationPresentationOptionAlert (4)
        completionHandler(1 | 4);
    }
}

// Always show legacy notifications when app is active
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

@end

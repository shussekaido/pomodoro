// Modern EventKit-based calendar service for Pomodoro

#import "PDCalendarService.h"
#import <EventKit/EventKit.h>

static NSString * const kPDCalendarIdentifierKey = @"calendarIdentifier";
static NSString * const kPDCalendarNameKey = @"selectedCalendar"; // keep backward compatible key name for UI
static NSString * const kPDActiveEventIdentifierKey = @"activeEventIdentifier";

@interface PDCalendarService ()
@property (nonatomic, strong) EKEventStore *eventStore;
@end

@implementation PDCalendarService

+ (instancetype)shared {
    static PDCalendarService *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PDCalendarService alloc] init];
    });
    return shared;
}

- (instancetype)init {
    if (self = [super init]) {
        _eventStore = [[EKEventStore alloc] init];
    }
    return self;
}

- (void)requestAccessWithCompletion:(void (^)(BOOL granted, NSError *error))completion {
    // Prefer write-only access on macOS 14+ if selector exists
    if ([_eventStore respondsToSelector:@selector(requestWriteOnlyAccessToEventsWithCompletion:)]) {
        // Suppress ARC warning by performSelector; cast signature loosely
        IMP imp = [_eventStore methodForSelector:@selector(requestWriteOnlyAccessToEventsWithCompletion:)];
        void (*func)(id, SEL, void (^)(BOOL, NSError *)) = (void *)imp;
        func(_eventStore, @selector(requestWriteOnlyAccessToEventsWithCompletion:), ^(BOOL granted, NSError *error){
            if (!granted && [_eventStore respondsToSelector:@selector(requestFullAccessToEventsWithCompletion:)]) {
                IMP impFull = [_eventStore methodForSelector:@selector(requestFullAccessToEventsWithCompletion:)];
                void (*funcFull)(id, SEL, void (^)(BOOL, NSError *)) = (void *)impFull;
                funcFull(_eventStore, @selector(requestFullAccessToEventsWithCompletion:), completion);
            } else {
                if (completion) completion(granted, error);
            }
        });
        return;
    }

    if ([_eventStore respondsToSelector:@selector(requestAccessToEntityType:completion:)]) {
        [_eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
            if (completion) completion(granted, error);
        }];
        return;
    }

    // Older macOS fallback: assume granted
    if (completion) completion(YES, nil);
}

- (EKSource *)iCloudSource {
    for (EKSource *source in self.eventStore.sources) {
        if (source.sourceType == EKSourceTypeCalDAV && [[source title] isEqualToString:@"iCloud"]) {
            return source;
        }
    }
    return nil;
}

- (EKCalendar *)calendarByIdentifier:(NSString *)identifier {
    if (!identifier) return nil;
    if ([self.eventStore respondsToSelector:@selector(calendarWithIdentifier:)]) {
        return [self.eventStore calendarWithIdentifier:identifier];
    }
    for (EKCalendar *cal in [self.eventStore calendarsForEntityType:EKEntityTypeEvent]) {
        if ([cal.calendarIdentifier isEqualToString:identifier]) return cal;
    }
    return nil;
}

- (EKCalendar *)calendarByName:(NSString *)name {
    if (name.length == 0) return nil;
    for (EKCalendar *cal in [self.eventStore calendarsForEntityType:EKEntityTypeEvent]) {
        if ([[cal title] isEqualToString:name]) return cal;
    }
    return nil;
}

- (EKCalendar *)resolveOrCreateCalendarNamed:(NSString *)calendarName error:(NSError **)error {
    if (calendarName.length == 0) {
        calendarName = @"Pomodoro";
    }

    // Try by stored identifier first
    NSString *storedId = [self storedCalendarIdentifier];
    if (storedId) {
        EKCalendar *cal = [self calendarByIdentifier:storedId];
        if (cal) {
            // Keep name in sync if changed
            [[NSUserDefaults standardUserDefaults] setObject:cal.title forKey:kPDCalendarNameKey];
            return cal;
        }
    }

    // Try by name
    EKCalendar *byName = [self calendarByName:calendarName];
    if (byName) {
        [self storeCalendar:byName];
        return byName;
    }

    // Create in iCloud if possible, otherwise in local default
    EKSource *targetSource = [self iCloudSource];
    if (!targetSource) {
        // fallback to default source
        for (EKSource *source in self.eventStore.sources) {
            if (source.sourceType == EKSourceTypeLocal) {
                targetSource = source; break;
            }
        }
        if (!targetSource) targetSource = self.eventStore.defaultCalendarForNewEvents.source;
    }

    EKCalendar *newCal = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:self.eventStore];
    newCal.source = targetSource;
    newCal.title = calendarName;
    NSError *saveErr = nil;
    BOOL ok = [self.eventStore saveCalendar:newCal commit:YES error:&saveErr];
    if (!ok) {
        if (error) *error = saveErr;
        return nil;
    }
    [self storeCalendar:newCal];
    return newCal;
}

- (NSArray<NSString *> *)writableCalendarTitles {
    NSMutableArray *titles = [NSMutableArray array];
    for (EKCalendar *cal in [self.eventStore calendarsForEntityType:EKEntityTypeEvent]) {
        if (cal.allowsContentModifications) {
            [titles addObject:cal.title ?: @""];
        }
    }
    return titles;
}

- (NSString *)storedCalendarIdentifier { return [[NSUserDefaults standardUserDefaults] objectForKey:kPDCalendarIdentifierKey]; }
- (NSString *)storedCalendarName { return [[NSUserDefaults standardUserDefaults] objectForKey:kPDCalendarNameKey]; }

- (void)storeCalendar:(EKCalendar *)calendar {
    if (!calendar) return;
    [[NSUserDefaults standardUserDefaults] setObject:calendar.calendarIdentifier forKey:kPDCalendarIdentifierKey];
    [[NSUserDefaults standardUserDefaults] setObject:calendar.title forKey:kPDCalendarNameKey];
}

- (EKEvent *)eventByIdentifier:(NSString *)eventId {
    if (!eventId) return nil;
    return [self.eventStore eventWithIdentifier:eventId];
}

- (EKCalendar *)currentCalendarOrResolve {
    NSString *name = [self storedCalendarName];
    NSError *err = nil;
    EKCalendar *cal = [self resolveOrCreateCalendarNamed:name error:&err];
    if (!cal && !err) {
        cal = self.eventStore.defaultCalendarForNewEvents;
        [self storeCalendar:cal];
    }
    return cal;
}

- (NSString *)startSessionWithTitle:(NSString *)title
                               notes:(NSString *)notes
                      durationMinutes:(NSInteger)minutes {
    EKCalendar *calendar = [self currentCalendarOrResolve];
    if (!calendar) return nil;

    NSDate *start = [NSDate date];
    NSDate *end = [start dateByAddingTimeInterval:(minutes * 60)];
    EKEvent *event = [EKEvent eventWithEventStore:self.eventStore];
    event.calendar = calendar;
    event.title = title ?: @"Pomodoro";
    event.notes = notes;
    event.startDate = start;
    event.endDate = end;
    event.timeZone = [NSTimeZone localTimeZone];

    NSError *err = nil;
    BOOL ok = [self.eventStore saveEvent:event span:EKSpanThisEvent commit:YES error:&err];
    if (!ok) {
        return nil;
    }
    NSString *identifier = event.eventIdentifier;
    if (identifier) {
        [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kPDActiveEventIdentifierKey];
    }
    return identifier;
}

- (BOOL)finishActiveSessionWithNotes:(NSString *)notes {
    NSString *eventId = [[NSUserDefaults standardUserDefaults] objectForKey:kPDActiveEventIdentifierKey];
    if (!eventId) return NO;
    EKEvent *event = [self eventByIdentifier:eventId];
    if (!event) return NO;
    event.endDate = [NSDate date];
    if (notes.length > 0) {
        if (event.notes.length > 0) {
            event.notes = [NSString stringWithFormat:@"%@\n%@", event.notes, notes];
        } else {
            event.notes = notes;
        }
    }
    NSError *err = nil;
    BOOL ok = [self.eventStore saveEvent:event span:EKSpanThisEvent commit:YES error:&err];
    if (ok) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPDActiveEventIdentifierKey];
    }
    return ok;
}

- (BOOL)deleteActiveSessionEvent {
    NSString *eventId = [[NSUserDefaults standardUserDefaults] objectForKey:kPDActiveEventIdentifierKey];
    if (!eventId) return NO;
    EKEvent *event = [self eventByIdentifier:eventId];
    if (!event) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPDActiveEventIdentifierKey];
        return NO;
    }
    NSError *err = nil;
    BOOL ok = [self.eventStore removeEvent:event span:EKSpanThisEvent commit:YES error:&err];
    if (ok) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPDActiveEventIdentifierKey];
    }
    return ok;
}

@end


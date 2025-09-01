// Modern EventKit-based calendar service for Pomodoro
#import <Foundation/Foundation.h>

@class EKEventStore, EKCalendar, EKEvent;

@interface PDCalendarService : NSObject

// Shared singleton for app-wide usage
+ (instancetype)shared;

// Request calendar access, preferring write-only on macOS 14+ when available
- (void)requestAccessWithCompletion:(void (^)(BOOL granted, NSError *error))completion;

// Resolve or create a calendar with the provided name in iCloud source, persist identifier
- (EKCalendar *)resolveOrCreateCalendarNamed:(NSString *)calendarName error:(NSError **)error;

// List available writable calendars' titles (for UI population)
- (NSArray<NSString *> *)writableCalendarTitles;

// Persisted identifiers/names handling
- (NSString *)storedCalendarIdentifier;
- (NSString *)storedCalendarName;
- (void)storeCalendar:(EKCalendar *)calendar;

// Session event lifecycle
- (NSString *)startSessionWithTitle:(NSString *)title
                               notes:(NSString *)notes
                      durationMinutes:(NSInteger)minutes;

- (BOOL)finishActiveSessionWithNotes:(NSString *)notes;
- (BOOL)deleteActiveSessionEvent;

@end


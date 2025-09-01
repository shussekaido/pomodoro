// Pomodoro Desktop - Copyright (c) 2009-2011, Ugo Landini (ugol@computer.org)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// * Neither the name of the <organization> nor the
// names of its contributors may be used to endorse or promote products
// derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "CalendarController.h"
#import "PDCalendarService.h"
#import "PomoNotifications.h"
#import "Pomodoro.h"

@implementation CalendarController

@synthesize calendarsCombo;


- (IBAction)initCalendars:(id)sender {
    [calendarsCombo removeAllItems];
    NSArray *titles = [[PDCalendarService shared] writableCalendarTitles];
    for (NSString *title in titles) {
        [calendarsCombo addItemWithObjectValue:title];
    }
    NSString *storedName = [[PDCalendarService shared] storedCalendarName];
    if (storedName.length > 0) {
        [calendarsCombo selectItemWithObjectValue:storedName];
    }
}

- (IBAction)calendarSelectionChanged:(id)sender {
    NSString *name = [[self calendarsCombo] stringValue];
    if (name.length == 0) return;
    NSError *err = nil;
    // Resolve or create chosen calendar, then store
    id cal = [[PDCalendarService shared] resolveOrCreateCalendarNamed:name error:&err];
    (void)cal; (void)err;
    [self initCalendars:self];
}

#pragma mark ---- Pomodoro notifications methods ----

- (void) pomodoroFinished:(NSNotification*) notification {

	if ([self checkDefault:@"calendarEnabled"]) {
        Pomodoro* pomo = [notification object];
        int duration = (int)lround(pomo.realDuration/60.0);
        NSString *notes = [NSString stringWithFormat:@"Ended. Duration: %d min. ExInt:%ld InInt:%ld",
                           duration, (long)_dailyExternalInterruptions, (long)_dailyInternalInterruptions];
        [[PDCalendarService shared] finishActiveSessionWithNotes:notes];
	}

}

-(void) pomodoroStarted:(NSNotification*) notification {
    if ([self checkDefault:@"calendarEnabled"]) {
        // Ensure access and calendar are prepared
        __weak typeof(self) weakSelf = self;
        [[PDCalendarService shared] requestAccessWithCompletion:^(BOOL granted, NSError *error) {
            if (!granted) return;
            NSString *title = [weakSelf bindCommonVariables:@"calendarEnd"]; // reuse existing template
            NSInteger initial = _initialTime;
            NSString *notes = [NSString stringWithFormat:@"Started. Planned: %ld min.", (long)initial];
            [[PDCalendarService shared] startSessionWithTitle:title notes:notes durationMinutes:initial];
        }];
    }
}

-(void) pomodoroReset:(NSNotification*) notification {
    if ([self checkDefault:@"calendarEnabled"]) {
        [[PDCalendarService shared] deleteActiveSessionEvent];
    }
}

-(void) pomodoroExternallyInterrupted:(NSNotification*) notification {
    if ([self checkDefault:@"calendarEnabled"]) {
        // Keep the event, still update at finish; no-op here
    }
}

-(void) pomodoroInternallyInterrupted:(NSNotification*) notification {
    if ([self checkDefault:@"calendarEnabled"]) {
        // Keep the event, still update at finish; no-op here
    }
}

#pragma mark ---- Lifecycle methods ----

- (void)awakeFromNib {
    // Prepare calendar access and ensure calendar exists (default name: Pomodoro)
    NSString *desiredName = [[PDCalendarService shared] storedCalendarName];
    if (desiredName.length == 0) desiredName = @"Pomodoro";
    [[PDCalendarService shared] requestAccessWithCompletion:^(BOOL granted, NSError *error) {
        if (granted) {
            NSError *resolveErr = nil;
            [[PDCalendarService shared] resolveOrCreateCalendarNamed:desiredName error:&resolveErr];
        }
    }];

    [self initCalendars:self];
    [self registerForPomodoro:_PMPomoStarted method:@selector(pomodoroStarted:)];
    [self registerForPomodoro:_PMPomoFinished method:@selector(pomodoroFinished:)];
    [self registerForPomodoro:_PMPomoReset method:@selector(pomodoroReset:)];
}



@end

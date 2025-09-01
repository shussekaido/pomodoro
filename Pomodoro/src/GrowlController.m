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

#import "GrowlController.h"
#import "GrowlNotifier.h"
#import "PomoNotifications.h"
#import "NotificationService.h"

@implementation GrowlController

@synthesize growl, growlStatus, growlEveryCombo;

#pragma mark ---- Method-independent notifications ----

-(void) notify:(NSString *)message title:(NSString *)title sticky:(BOOL)sticky {
    (void)sticky; // Not applicable for UN notifications; system decides style.
    [[NotificationService shared] postWithTitle:title body:message identifier:nil];
}

#pragma mark ---- Growl ----

-(IBAction) checkGrowl:(id)sender {
    [[NotificationService shared] requestAuthorizationIfNeeded];
    [growlStatus setImage:yellowButtonImage];
    [sender setToolTip:@"Notifications will be requested on first use."];
    [growlStatus setToolTip:@"Notifications will be requested on first use."];
    [[NotificationService shared] postWithTitle:@"Pomodoro"
                                          body:@"Test notification"
                                     identifier:nil];
}


#pragma mark ---- Pomodoro notifications methods ----

-(void) pomodoroStarted:(NSNotification*) notification {

    if ([self checkDefault:@"notificationAtStartEnabled"] || [self checkDefault:@"growlAtStartEnabled"]) {
        BOOL sticky = [self checkDefault:@"stickyStartEnabled"];
        NSString *msg = [self bindCommonVariables:@"notificationStart"];
        if (!msg) msg = [self bindCommonVariables:@"growlStart"];
        [self notify: msg title:NSLocalizedString(@"Pomodoro started",@"Pomodoro started header") sticky:sticky];
    }
}

- (void) interrupted {
    
    NSString* interruptTimeString = [[[NSUserDefaults standardUserDefaults] objectForKey:@"interruptTime"] stringValue];
    if ([self checkDefault:@"notificationAtInterruptEnabled"] || [self checkDefault:@"growlAtInterruptEnabled"]) {

		NSString* growlString = [self bindCommonVariables:@"growlInterrupt"];		
        [self notify: [growlString stringByReplacingOccurrencesOfString:@"$secs" withString:interruptTimeString] title:NSLocalizedString(@"Pomodoro interrupted",@"Pomodoro interrupted header") sticky:NO];
    }
    
}

-(void) pomodoroExternallyInterrupted:(NSNotification*) notification {
    
	[self interrupted];

}

-(void) pomodoroInternallyInterrupted:(NSNotification*) notification {
    
	[self interrupted];
    
}

-(void) pomodoroInterruptionMaxTimeIsOver:(NSNotification*) notification {
    
    if ([self checkDefault:@"notificationAtInterruptOverEnabled"] || [self checkDefault:@"growlAtInterruptOverEnabled"]) {
        NSString *msg = [self bindCommonVariables:@"notificationInterruptOver"];
        if (!msg) msg = [self bindCommonVariables:@"growlInterruptOver"];
        [self notify:msg title:NSLocalizedString(@"Pomodoro reset",@"Pomodoro reset header") sticky:NO];
    }

}

-(void) pomodoroReset:(NSNotification*) notification {
    
    if ([self checkDefault:@"notificationAtResetEnabled"] || [self checkDefault:@"growlAtResetEnabled"]) {
        NSString *msg = [self bindCommonVariables:@"notificationReset"];
        if (!msg) msg = [self bindCommonVariables:@"growlReset"];
        [self notify:msg title:NSLocalizedString(@"Pomodoro reset",@"Pomodoro reset header") sticky:NO];
    }
    
}

-(void) pomodoroResumed:(NSNotification*) notification {
    
    if ([self checkDefault:@"notificationAtResumeEnabled"] || [self checkDefault:@"growlAtResumeEnabled"]) {
        NSString *msg = [self bindCommonVariables:@"notificationResume"];
        if (!msg) msg = [self bindCommonVariables:@"growlResume"];
        [self notify:msg title:NSLocalizedString(@"Pomodoro resumed",@"Pomodoro resumed header") sticky:NO];
    }
    
}

-(void) breakStarted:(NSNotification*) notification {
    
}

-(void) breakFinished:(NSNotification*) notification {
    
    if ([self checkDefault:@"notificationAtBreakFinishedEnabled"] || [self checkDefault:@"growlAtBreakFinishedEnabled"]) {
        BOOL sticky = [self checkDefault:@"stickyBreakFinishedEnabled"];
        NSString *msg = [self bindCommonVariables:@"notificationBreakFinished"];
        if (!msg) msg = [self bindCommonVariables:@"growlBreakFinished"];
        [self notify:msg title:NSLocalizedString(@"Pomodoro break finished",@"Pomodoro break finished header") sticky:sticky];
    }
    
}

-(void) pomodoroFinished:(NSNotification*) notification {
    
    if ([self checkDefault:@"notificationAtEndEnabled"] || [self checkDefault:@"growlAtEndEnabled"]) {
        BOOL sticky = [self checkDefault:@"stickyEndEnabled"];
        NSString *msg = [self bindCommonVariables:@"notificationEnd"];
        if (!msg) msg = [self bindCommonVariables:@"growlEnd"];
        [self notify:msg title:NSLocalizedString(@"Pomodoro finished",@"Pomodoro finished header") sticky:sticky];
    }
    
}

- (void) oncePerSecondBreak:(NSNotification*) notification {
    
}

- (void) oncePerSecond:(NSNotification*) notification {
    
    NSInteger time = [[notification object] integerValue];
    NSInteger timePassed = (_initialTime*60) - time;
	NSString* timePassedString = [NSString stringWithFormat:@"%ld", timePassed/60];
	NSString* timeString = [NSString stringWithFormat:@"%ld", time/60];
	
    if (timePassed%(60 * _growlEveryTimeMinutes) == 0 && time!=0) {	
        if ([self checkDefault:@"notificationAtEveryEnabled"] || [self checkDefault:@"growlAtEveryEnabled"]) {
            NSString* base = [self bindCommonVariables:@"notificationEvery"]; if (!base) base = [self bindCommonVariables:@"growlEvery"];
            NSString* mins = [[[NSUserDefaults standardUserDefaults] objectForKey:@"growlEveryTimeMinutes"] stringValue];
            NSString* msg = [base stringByReplacingOccurrencesOfString:@"$mins" withString:mins];
            msg = [msg stringByReplacingOccurrencesOfString:@"$passed" withString:timePassedString];
            msg = [msg stringByReplacingOccurrencesOfString:@"$time" withString:timeString];
            [self notify:msg title:@"Pomodoro ticking" sticky:NO];
        }
    }
}

#pragma mark ---- Lifecycle methods ----

- (void)awakeFromNib {
    [self registerForAllPomodoroEvents];
    [[NotificationService shared] requestAuthorizationIfNeeded];

    redButtonImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"red" ofType:@"png"]];
    greenButtonImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"green" ofType:@"png"]];
    yellowButtonImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"yellow" ofType:@"png"]];

    [growlEveryCombo addItemWithObjectValue:[NSNumber numberWithInt:2]];
    [growlEveryCombo addItemWithObjectValue:[NSNumber numberWithInt:5]];
    [growlEveryCombo addItemWithObjectValue:[NSNumber numberWithInt:10]];
}


@end

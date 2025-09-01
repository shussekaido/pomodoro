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

#import "PomodoroController.h"
#import "GrowlNotifier.h"
#import "Pomodoro.h"
#import "Binder.h"
#import "PomodoroDefaults.h"
#import "AboutController.h"
#import "StatsController.h"
#import "SplashController.h"
#import "ShortcutController.h"
#import "PomodoroNotifier.h"
#import "PomoNotifications.h"
#import "NotificationService.h"
#include <CoreServices/CoreServices.h>

@implementation PomodoroController

@synthesize startPomodoro, finishPomodoro, invalidatePomodoro, interruptPomodoro, internalInterruptPomodoro, resumePomodoro;
@synthesize growl, pomodoro, longBreakCounter, longBreakCheckerTimer;
@synthesize prefs, scriptPanel, namePanel, breakCombo, initialTimeCombo, interruptCombo, longBreakCombo, longBreakResetComboTime, pomodorosForLong;
@synthesize pomodoroMenu, tabView, toolBar;

#pragma mark ---- Helper methods ----

- (void) showTimeOnStatusBar:(NSInteger) time {	
	if ([self checkDefault:@"showTimeOnStatusEnabled"]) {
		[statusItem setTitle:[NSString stringWithFormat:@" %.2d:%.2d",time/60, time%60]];
	} else {
		[statusItem setTitle:@""];
	}
}

- (void) longBreakCheckerFinished {
    
    //NSLog(@"LongBreak Timer reset!");
    longBreakCounter = 0;
    longBreakCheckerTimer = nil;
    
}

#pragma mark ---- Window delegate methods ----


- (void)windowDidResignKey:(NSNotification *)notification {
    
    // Commit Editing still in place when closing a panel or losing focus
    [notification.object makeFirstResponder:nil];

}

#pragma mark ---- KVO Utility ----

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    	
	if ([keyPath isEqualToString:@"showTimeOnStatusEnabled"]) {		
		[self showTimeOnStatusBar: _initialTime * 60];		
	} else if ([keyPath isEqualToString:@"initialTime"]) {
        NSInteger duration = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
        [pomodoro setDurationMinutes:duration];
        [self showTimeOnStatusBar: duration * 60];
        
    } else if ([keyPath hasSuffix:@"Volume"]) {
		NSInteger volume = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
		NSInteger oldVolume = [[change objectForKey:NSKeyValueChangeOldKey] intValue];
		
		if (volume != oldVolume) {
			float newVolume = volume/100.0;
			if ([keyPath isEqual:@"ringVolume"]) {
				[ringing setVolume:newVolume];
				[ringing play];
			}
			if ([keyPath isEqual:@"ringBreakVolume"]) {
				[ringingBreak setVolume:newVolume];
				[ringingBreak play];
			}
			if ([keyPath isEqual:@"tickVolume"]) {
				[tick setVolume:newVolume];
				[tick play];
			}
		}
	} 
	
}


#pragma mark ---- Key management methods ----

-(void) keyMute {
	BOOL muteState = ![self checkDefault:@"mute"];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:muteState] forKey:@"mute"];
}

-(void) keyStart {
	if ([self.startPomodoro isEnabled]) [self start:nil];
}

-(void) keyReset {
	if ([self.invalidatePomodoro isEnabled]) [self reset:nil];
}

-(void) keyInterrupt {
	if ([self.interruptPomodoro isEnabled]) [self externalInterrupt:nil];
}

-(void) keyInternalInterrupt {
	if ([self.internalInterruptPomodoro isEnabled]) [self internalInterrupt:nil];
}

-(void) keyResume {
	if ([self.resumePomodoro isEnabled]) [self resume:nil];
}

-(void) keyQuickStats {
	
	[self quickStats:nil];

}

#pragma mark ---- Toolbar methods ----

-(IBAction) toolBarIconClicked: (id) sender {
    
    [tabView selectTabViewItem:[tabView tabViewItemAtIndex:[sender tag]]];
    
}

#pragma mark ---- Menu management methods ----

- (void) updateMenu {
	enum PomoState state = pomodoro.state;
	
	NSImage * image;
	NSImage * alternateImage;
	switch (state) {
		case PomoTicking:
			image = pomodoroImage;
			alternateImage = pomodoroNegativeImage;
			break;
		case PomoInterrupted:
			image = pomodoroFreezeImage;
			alternateImage = pomodoroNegativeFreezeImage;
			break;
		case PomoInBreak:
			image = pomodoroBreakImage;
			alternateImage = pomodoroNegativeBreakImage;
			break;
		default: // PomoReadyToStart
			image = pomodoroImage;
			alternateImage = pomodoroNegativeImage;
			break;
	}
    
	[statusItem setImage:image];
	[statusItem setAlternateImage:alternateImage];
		
	int startState;
	switch (state) {
		case PomoReadyToStart:
			startState = NSOnState;
			break;
		case PomoTicking:
		case PomoInterrupted:
		case PomoInBreak:
			startState = NSOffState;
			break;
	}
	[startPomodoro setState:startState];
	[finishPomodoro setEnabled:state == PomoTicking || state == PomoInBreak];
	[invalidatePomodoro setEnabled:state != PomoReadyToStart];
	[resumePomodoro setEnabled:state == PomoInterrupted];
	[interruptPomodoro setEnabled:state == PomoTicking];
	[internalInterruptPomodoro setEnabled:state == PomoTicking];
}

// ... (rest of file unchanged except awakeFromNib addition)

#pragma mark ---- Lifecycle methods ----

+ (void)initialize { 
    
	[PomodoroDefaults setDefaults];
	
} 

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    NSLog(@"Pomodoro terminating...");
    [stats saveState];
    [prefs close];
}
	  
- (void)awakeFromNib {
    
    [self registerForAllPomodoroEvents];
    // (Removed debug file logging)
    // Ensure notifications authorization requested on launch
    [[NotificationService shared] requestAuthorizationIfNeeded];
    
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

	pomodoroImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoro" ofType:@"png"]];
	pomodoroBreakImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoroBreak" ofType:@"png"]];
	pomodoroFreezeImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoroFreeze" ofType:@"png"]];
	pomodoroNegativeImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoro_n" ofType:@"png"]];
	pomodoroNegativeBreakImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoroBreak_n" ofType:@"png"]];
	pomodoroNegativeFreezeImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pomodoroFreeze_n" ofType:@"png"]];

	ringing = [NSSound soundNamed:@"ring.wav"];
	ringingBreak = [NSSound soundNamed:@"ringBreak.wav"];
	tick = [NSSound soundNamed:@"tick.wav"];
	[statusItem setImage:pomodoroImage];
	[statusItem setAlternateImage:pomodoroNegativeImage];
		
	[ringing setVolume:_ringVolume/100.0];
	[ringingBreak setVolume:_ringBreakVolume/100.0];
	[tick setVolume:_tickVolume/100.0];

	[initialTimeCombo addItemWithObjectValue: [NSNumber numberWithInt:25]];
	[initialTimeCombo addItemWithObjectValue: [NSNumber numberWithInt:30]];
	[initialTimeCombo addItemWithObjectValue: [NSNumber numberWithInt:35]];
	
    [initialTimeComboInStart addItemWithObjectValue: [NSNumber numberWithInt:25]];
	[initialTimeComboInStart addItemWithObjectValue: [NSNumber numberWithInt:30]];
	[initialTimeComboInStart addItemWithObjectValue: [NSNumber numberWithInt:35]];
    
	[interruptCombo addItemWithObjectValue: [NSNumber numberWithInt:15]];
	[interruptCombo addItemWithObjectValue: [NSNumber numberWithInt:20]];
	[interruptCombo addItemWithObjectValue: [NSNumber numberWithInt:25]];
	[interruptCombo addItemWithObjectValue: [NSNumber numberWithInt:30]];
	[interruptCombo addItemWithObjectValue: [NSNumber numberWithInt:45]];
	
	[breakCombo addItemWithObjectValue: [NSNumber numberWithInt:3]];
	[breakCombo addItemWithObjectValue: [NSNumber numberWithInt:5]];
	[breakCombo addItemWithObjectValue: [NSNumber numberWithInt:7]];
	
	[longBreakCombo addItemWithObjectValue: [NSNumber numberWithInt:10]];
	[longBreakCombo addItemWithObjectValue: [NSNumber numberWithInt:15]];
	[longBreakCombo addItemWithObjectValue: [NSNumber numberWithInt:20]];
    
    [longBreakResetComboTime addItemWithObjectValue: [NSNumber numberWithInt:3]];
	[longBreakResetComboTime addItemWithObjectValue: [NSNumber numberWithInt:5]];
	[longBreakResetComboTime addItemWithObjectValue: [NSNumber numberWithInt:7]];
	
	[pomodorosForLong addItemWithObjectValue: [NSNumber numberWithInt:4]];
	[pomodorosForLong addItemWithObjectValue: [NSNumber numberWithInt:6]];
	[pomodorosForLong addItemWithObjectValue: [NSNumber numberWithInt:8]];
			
	[statusItem setToolTip:NSLocalizedString(@"Pomodoro Time Management",@"Status Tooltip")];
	[statusItem setHighlightMode:YES];
	[statusItem setMenu:pomodoroMenu];
	[self showTimeOnStatusBar: _initialTime * 60];
	
    [toolBar setSelectedItemIdentifier:@"Pomodoro"];

    [pomodoro setDurationMinutes:_initialTime];
    pomodoroNotifier = [[PomodoroNotifier alloc] init];
	[pomodoro setDelegate: pomodoroNotifier];
    
	stats = [[StatsController alloc] init];
	[stats window];

	GetCurrentProcess(&psn);
    
	[self observeUserDefault:@"ringVolume"];
	[self observeUserDefault:@"ringBreakVolume"];
	[self observeUserDefault:@"tickVolume"];
	[self observeUserDefault:@"initialTime"];
	
	[self observeUserDefault:@"showTimeOnStatusEnabled"];
	
	if ([self checkDefault:@"showSplashScreenAtStartup"]) {
		[self help:nil];
	}	
    
}


@end
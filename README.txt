--------
Pomodoro
--------

Pomodoro is an antiprocrastination application that helps in Getting Things Done. 
It is a simple but effective way to manage your time and to boost your productivity to higher levels. 
Can be used for programming, studying, writing, cooking or simply concentrating on something important.
 
You can find more informations on the Pomodoro Technique on http://www.pomodorotechnique.com/
Updates, source code, new releases, manual and fixes on http://pomodoro.ugolandini.com

----------
Developers
----------

Project lead: Ugo Landini
Active Developers: Ugo Landini, Pascal Bihler
Retired Developers: 
 
-------
License
-------
This code is released under BSD license (see License.txt for details) and contains other OSS BSD licensed code:
Growl framework: http://growl.info/
BGHud Appkit: http://code.google.com/p/bghudappkit/

This software contains Waffle Software licensed code:
Shortcut Recorder: http://wafflesoftware.net/shortcut/

Matt Gemmell licensed code:
MGTwitterEngine: http://svn.cocoasourcecode.com/MGTwitterEngine/

Sound samples come from http://www.freesound.org and are licensed under Creative Commons http://creativecommons.org/licenses/sampling+/1.0/

--------------
Building notes
--------------


1) Remove Code signing identity if present (should not, but sometimes I push it back)

Xcode 4.3+ (tips from @sashalaundy):	
1) Product > Edit Scheme
2) At top set Scheme to "Pomodoro" and Destination to "My Mac __-bit"
3) On left select Archive
4) Type in Archive Name "Pomodoro"
5) Hit OK
6) Product > Archive - Xcode builds and then opens Organizer with archive selected
7) Hit Distribute
8) Choose Export as "Application"

Xcode 4:
1) Build a copy for archiving: Product menu -> Build for -> Build for Archiving
2) Open the organizer: Window menu -> Organizer
3) Create a copy of the application: Hit the Share button in the Organizer
4) Choose "Application" from the drop-down menu, and then save it to your Applications folder. 

Xcode 3: (not actively maintained)
1) Should work, but I don't maintain it anymore.

---------------------------
Calendar Integration (EventKit)
---------------------------

Pomodoro can log each session to a calendar using EventKit (macOS 13+).

- Enable logging: open Preferences → Calendar and check the calendar option.
- Calendar creation: on first use, Pomodoro creates or reuses an iCloud calendar named "Pomodoro" (or the name you choose) and stores its identifier.
- Permissions: on first launch, macOS prompts for Calendar access. On macOS 14/15, the app requests write‑only access and falls back to full access if needed.
- Choosing a calendar: the calendar picker lists writable calendars. Selecting a name resolves/creates that calendar and persists the choice.
- Event lifecycle: starting a pomodoro creates an event from now to planned end; finishing updates the event end time to now; reset deletes the active event.

Troubleshooting
- Ensure the "Pomodoro" calendar is visible (checked) in Apple Calendar’s sidebar (under iCloud or On My Mac).
- Check permissions: System Settings → Privacy & Security → Calendars → enable "Pomodoro".
- Reset selection: run
  `defaults delete com.ugolandini.Pomodoro calendarIdentifier; defaults delete com.ugolandini.Pomodoro selectedCalendar`
  then relaunch and re‑enable the calendar option.
- Logs: run `log stream --style syslog --predicate 'process == "Pomodoro"'` while starting/finishing a session.

-------
Twitter
-------
If you want to use Twitter integration, you must have a consumerKey and a secretKey for oAuth/xAuth authentication. You must obtain the secrets from twitter site and then add them in src/TwitterSecrets.h 

#define _consumerkey @"your key" 
#define _secretkey @"your other key"

If you are not interested in Twitter, just don't activate the twitter integration.

------------------------------
Thanks, in no particular order
------------------------------
Everaldo for the gorgeous new icons
Pedro Murillo
Michael Bedward
Dieter Vermandere
Paul Schmidt
Sina Samangooei <sinjax@gmail.com> for debugging (and fixing!)
Alexander Klimetschek
Konrad Mitchell Lawson
Stefano Linguerri for the initial graphic design 
Giulio Cesare Solaroli for the old icons
Luca Ceppelli
Roberto Turchetti
Sergio Bossa 
Andrew Rimmer
Timothy Davis
Simone Gentilini
Francesco Mondora
Michele Mondora
Andy Palmer
Brandon Murray
Valiev Omar
Alexander Willner 
C.Kuehne 
R.Altimari
P.Bihler

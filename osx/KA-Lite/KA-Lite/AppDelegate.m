//
//  AppDelegate.m
//  KA-Lite
//
//  Created by cyril on 1/20/15.
//  Copyright (c) 2015 FLE. All rights reserved.
//

// 
// Notes: Possible issues with OSX 10.10 or higher:
// * http://www.dowdandassociates.com/blog/content/howto-set-an-environment-variable-in-mac-os-x-slash-etc-slash-launchd-dot-conf/
// 

#import "AppDelegate.h"

@import Foundation;

@interface AppDelegate ()
//    @property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

@synthesize startKalite, stopKalite, openInBrowserMenu;


//REF http://objcolumnist.com/2009/08/09/reopening-an-applications-main-window-by-clicking-the-dock-icon/
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if(flag==NO) {
        [self showPreferences];
    }
    return YES;	
}


// TODO(amodia): Show menu bar on dock icon.
//- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
//    return self.statusMenu;
//}


//<##>applicationDidFinishLaunching
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    // Setup the status menu item.
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setImage:[NSImage imageNamed:@"favicon"]];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setHighlightMode:YES];
    [self.statusItem setToolTip:@"Click to show the KA-Lite menu items."];

    // Set the default status.
    self.status = statusCouldNotDetermineStatus;
    [self getKaliteStatus];
    
    // We need to show preferences if the following does not exist:
    // 1. database does not exist
    // 2. symlinked `kalite` executable
    // Apply button is clicked, we run `kalite manage setup`.
    bool mustShowPreferences = false;
    @try {
        checkEnvVars();
        NSString *database = getDatabasePath();
        if (!pathExists(database)) {
            NSLog(@"Database not found, must show preferences.");
            mustShowPreferences = true;
        } else {
            NSLog([NSString stringWithFormat:@"FOUND database at %@!", database]);
        }

        NSString *kalite = getUsrBinKalite();
        if (!pathExists(kalite)) {
            NSLog(@"kalite executable not found, must show preferences.");
            mustShowPreferences = true;
            [self showStatus:statusFailedToStart];
            [self savePreferences];
            
        } else {
            NSLog([NSString stringWithFormat:@"FOUND kalite at %@!", kalite]);
        }
        showNotification(@"KA Lite is now loaded.");
    }
    @catch (NSException *ex) {
        NSLog(@"KA Lite had an Error: %@", ex);
    }
    
    void *sel = @selector(closeSplash);
    if (mustShowPreferences) {
        sel = @selector(showPreferences);
    }
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:sel userInfo:nil repeats:NO];
    [self startKaliteTimer];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    // TODO(cpauya): Confirm quit action from user.
    if (kaliteExists()) {
        showNotification(@"Stopping and quitting the application...");
        [self runKalite:@"stop"];
    }
}


/********************
  Useful Methods
********************/


BOOL checkEnvVars() {
    // MUST: Check the KALITE_PYTHON environment variable
    // and default it to the .app Resources folder if not yet set.
    NSString *pyrun = getEnvVar(@"KALITE_PYTHON");
    
    /*
    //TODO(amodia): Check the KALITE_PYTHON environment variable.
    if (!pathExists(pyrun)) {
        if (!setEnvVars(FALSE)) {
            NSString *msg = @"FAILED to set environment variables!";
            showNotification(msg);
            return FALSE;
        };
    }
    */
    // TODO(cpauya): Just a debug trace
    pyrun = getPyrunBinPath(true);
    NSLog([NSString stringWithFormat:@"Pyrun value: %@", pyrun]);
    return TRUE;
}


- (IBAction)clearLogs:(id)sender {
    self.taskLogs.string = @"";
}


- (void) displayLogs:(NSString *)outStr {
    dispatch_sync(dispatch_get_main_queue(), ^{
        //REF: http://stackoverflow.com/questions/10772033/get-current-date-time-with-nsdate-date
        //Get the current date time
        NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
        NSString *dateStr = [dateFormatter stringFromDate:[NSDate date]];
        
        NSString *str = [self.taskLogs.string stringByAppendingString:[NSString stringWithFormat:@"\n%@ %@", dateStr, outStr]];
        self.taskLogs.string = str;
        // Scroll to end of outputText field
        NSRange range;
        range = NSMakeRange([self.taskLogs.string length], 0);
        [self.taskLogs scrollRangeToVisible:range];
    });
}


- (void) runTask:(NSString *)command {
    NSString *pyrun;
    NSString *kalitePath;
    NSString *statusStr;
    NSMutableDictionary *kaliteEnv;
    
    statusStr = @"status";
    
    // Set loading indicator icon.
    if (command != statusStr) {
        [self.statusItem setImage:[NSImage imageNamed:@"loading"]];
    }
    
    self.processCounter += 1;
    
    pyrun = getPyrunBinPath(true);
    kalitePath = getUsrBinKalite();
    
    kaliteEnv = [[NSMutableDictionary alloc] init];

    NSTask* task = [[NSTask alloc] init];
    NSString *kaliteCommand = [NSString stringWithFormat:@"%@ %@", kalitePath, command];
    NSArray *array = [kaliteCommand componentsSeparatedByString:@" "];
    
    [task setLaunchPath: pyrun];
    [task setArguments: array];
    
    //REF: http://stackoverflow.com/questions/9965360/async-execution-of-shell-command-not-working-properly
    //REF: http://www.raywenderlich.com/36537/nstask-tutorial
    
    NSPipe *pipeOutput = [NSPipe pipe];
    task.standardOutput = pipeOutput;
    task.standardError = pipeOutput;
    
    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
        NSData *data = [file availableData]; // this will read to EOF, so call only once
        NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        NSString *outStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self displayLogs:outStr];
    }];
    
    [task launch];
    
}


NSString *getResourcePath(NSString *pathToAppend) {
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:pathToAppend];
    path = [path stringByStandardizingPath];
    return path;
}


NSString *getDatabasePath() {
    // Defaults to ~/.kalite/ folder so check there for now.
    // TODO(cpauya): Use the KALITE_HOME env var if it exists.
    NSString *database = @"~/.kalite/database/data.sqlite";
    database = [database stringByStandardizingPath];
    return database;
}


BOOL pathExists(NSString *path) {
    // REF: http://www.exampledb.com/objective-c-check-if-file-exists.htm
    // REF: http://www.digitaledgesw.com/node/31
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
    return exists;
}


NSString *thisOrOther(NSString *this, NSString *other) {
    // Accepts two arguments and returns the first if it has a value, else the other.
    if (this.length > 0) {
        return this;
    }
    return other;
}


/*
//<##>getKaliteDir
NSString *getKaliteDir(BOOL useEnvVar) {
    // Returns the path of `ka-lite` directory if it exists or an empty string otherwise.
    // If `useEnvVar` is set, get the `KALITE_DIR` from the environment variables and use it if valid.
    NSString *kaliteDir = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ka-lite"];
    if (useEnvVar) {
        // Use the KALITE_DIR environment variable if set.
        NSString *var = getEnvVar(@"KALITE_DIR");
        if (pathExists(var)) {
            kaliteDir = var;
        }
    }
    kaliteDir = [kaliteDir stringByStandardizingPath];
    if (pathExists(kaliteDir)){
        return kaliteDir;
    }
    return @"";
}
*/


NSString *getKaliteBinPath() {
    // Returns the path of `pyrun-2.7/bin/kalite` if it exists or an empty string otherwise.
    NSString *pyrunDir = getPyrunBinPath(true);
    NSString *kalitePath = [pyrunDir stringByAppendingString:@"/../kalite"];
    kalitePath = [kalitePath stringByStandardizingPath];
    if (pathExists(kalitePath)){
        return kalitePath;
    }
    return @"";
}


NSString *getPyrunBinPath(BOOL useEnvVar) {
    // Returns the path of `pyrun` binary if it exists or an empty string otherwise.
    // If `useEnvVar` is set, get the `KALITE_PYTHON` from the environment variables and use it if valid.
    NSString *pyrun = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"pyrun-2.7/bin/pyrun"];
    if (useEnvVar) {
        // Use the KALITE_PYTHON environment variable if set.
        NSString *var = getEnvVar(@"KALITE_PYTHON");
        if (pathExists(var) ) {
            pyrun = var;
        }
    }
    pyrun = [pyrun stringByStandardizingPath];
    if (pathExists(pyrun)){
        return pyrun;
    }
    return @"";
}


BOOL kaliteExists() {
    NSString *kalitePath = getKaliteBinPath();
    return pathExists(kalitePath);
}


BOOL pyrunExists() {
    NSString *pyrun = getPyrunBinPath(true);
    return pathExists(pyrun);
}


// REF: http://objc.toodarkpark.net/Foundation/Classes/NSTask.html
-(id)init{
    self = [super init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkRunTask:)
                                                 name:NSTaskDidTerminateNotification
                                               object:nil];
    return self;
}


- (enum kaliteStatus)checkRunTask:(NSNotification *)aNotification{
    NSArray *taskArguments;
    NSArray *statusArguments;
    NSString *kalitePath = getUsrBinKalite();
    enum kaliteStatus oldStatus = self.status;
    
    int status = [[aNotification object] terminationStatus];

    taskArguments = [[aNotification object] arguments];
    statusArguments = [[NSArray alloc]initWithObjects:kalitePath, @"status", nil];
    NSSet *taskArgsSet = [NSSet setWithArray:taskArguments];
    NSSet *statusArgsSet = [NSSet setWithArray:statusArguments];
    
    if (self.processCounter >= 1) {
        self.processCounter -= 1;
    }
    if (self.processCounter != 0) {
        return self.status;
    }
    
    if (checkUsrBinKalitePath()) {
        if ([taskArgsSet isEqualToSet:statusArgsSet]) {
            // MUST: The result is on the 9th bit of the returned value.  Not sure why this
            // is but maybe because of the returned values from the `system()` call.  For now
            // we shift 8 bits to the right until we figure this one out.  TODO(cpauya): fix later
            if (status >= 255) {
                status = status >> 8;
            }
            self.status = status;
            if (oldStatus != status) {
                [self showStatus:self.status];
            }
            return self.status;
        } else {
            // If command is not "status", run `kalite status` to get status of ka-lite.
            // We need this check because this may be called inside the kA-Lite timer.
            NSLog(@"Fetching `kalite status`...");
            [self showStatus:self.status];
            [self getKaliteStatus];
            return self.status;
        }
    } else {
        self.status = statusCouldNotDetermineStatus;
        [self showStatus:self.status];
        showNotification(@"The `kalite` executable does not exist!");
    }
    return self.status;
}


- (enum kaliteStatus)runKalite:(NSString *)command {
    @try {
        // MUST: This will make sure the process to run has access to the environment variable
        // because the .app may be loaded the first time.
        
        if (checkUsrBinKalitePath()) {
            [self runTask:command];
        }
    }
    @catch (NSException *ex) {
        self.status = statusCouldNotDetermineStatus;
        NSLog(@"Error running `kalite` %@", ex);
    }
    return self.status;
}


void alert(NSString *message) {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}


BOOL confirm(NSString *message) {
    NSAlert *confirm = [[NSAlert alloc] init];
    [confirm addButtonWithTitle:@"OK"];
    [confirm addButtonWithTitle:@"Cancel"];
    [confirm setMessageText:message];
    if ([confirm runModal] == NSAlertFirstButtonReturn) {
        return TRUE;
    }
    return FALSE;
}


void showNotification(NSString *subtitle) {
    // REF: http://stackoverflow.com/questions/12267357/nsusernotification-with-custom-soundname?rq=1
    // TODO(cpauya): These must be ticked by user on preferences if they want notifications, sounds, or not.
    NSUserNotification* notification = [[NSUserNotification alloc]init];
    notification.title = @"KA-Lite";
    notification.subtitle = subtitle;
    notification.soundName = @"Basso.aiff";
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    // The notification may be optional (based on user preferences) but we must show it on the logs.
    NSLog(subtitle);
}


// REF: http://stackoverflow.com/a/26423271/845481
// Check IF one String contains the same characters as another string
- (BOOL)string:(NSString *)string containsAllCharactersInString:(NSString *)charString {
    NSUInteger stringLen = [string length];
    NSUInteger charStringLen = [charString length];
    for (NSUInteger i = 0; i < charStringLen; i++) {
        unichar c = [charString characterAtIndex:i];
        BOOL found = NO;
        for (NSUInteger j = 0; j < stringLen && !found; j++)
            found = [string characterAtIndex:j] == c;
        if (!found)
            return NO;
    }
    return YES;
}


//<##>runRootCommands
BOOL runRootCommands(NSString *command) {
//    NSString *msg = [NSString stringWithFormat:@"Running root command/s: %@...", command];
//    showNotification(msg);
    
    NSDictionary *errorInfo = runAsRoot(command);
    if (errorInfo != nil) {
//        msg = [NSString stringWithFormat:@"FAILED command/s %@ with ERROR: %@", command, errorInfo];
//        showNotification(msg);
        return FALSE;
    }
//    msg = [NSString stringWithFormat:@"Done running root command/s %@.", command];
//    showNotification(msg);
    return TRUE;
}


//<##>setLaunchAgent
NSString *getLaunchAgentCommand(NSString *source, NSString *target) {
    if (pathExists(source)) {
        return [NSString stringWithFormat:@"cp '%@' '%@'", source, target];
    }
    return nil;
}


// Not used for now but is useful to re-run the command individually later.
BOOL setLaunchAgent(NSString *source, NSString *target) {
    // Needs to run as root.
    NSString *msg;
    if (pathExists(source)) {
        msg = [NSString stringWithFormat:@"Copying %@ to %@...", source, target];
        showNotification(msg);
        
        NSString *command = [NSString stringWithFormat:@"cp '%@' '%@'", source, target];
        NSDictionary *errorInfo = runAsRoot(command);
        if (errorInfo != nil) {
            msg = [NSString stringWithFormat:@"FAILED command %@ with ERROR: %@", command, errorInfo];
            showNotification(msg);
            return FALSE;
        }
        msg = [NSString stringWithFormat:@"Done copying %@ to %@.", source, target];
        showNotification(msg);
    } else {
        msg = [NSString stringWithFormat:@"Source %@ OR target: %@ does not exist!", source, target];
        showNotification(msg);
        return FALSE;
    }
    return TRUE;
}


NSString *getUsrBinKalite() {
    return @"/usr/bin/kalite";
}


BOOL *checkUsrBinKalitePath() {
    NSString *kalitePath = @"/usr/bin/kalite";
    if (pathExists(kalitePath)) {
        return TRUE;
    }
    return false;
}


NSDictionary *runAsRoot(NSString *command) {
    // This will run an AppleScript command with admin privileges, thereby prompting the user to
    // input the admin password so script can continue.
    // REF: http://stackoverflow.com/questions/4599447/cocoa-gaining-root-access-for-nsfilemanager
    // REF: https://developer.apple.com/library/mac/samplecode/EvenBetterAuthorizationSample/Introduction/Intro.html
    
    // TODO(cpauya): This was supposed to be the approach but doesn't work since we need
    // admin privileges for symlinking to the target /usr/local/bin/.
    // This seemed hard, so resorted to running an Apple script for now.
    // REF: http://stackoverflow.com/questions/4599447/cocoa-gaining-root-access-for-nsfilemanager
    //        BOOL result = [fileMgr linkItemAtPath:kalitePath toPath:target error:&err];
    //        BOOL result = [fileMgr createSymbolicLinkAtPath:kalitePath withDestinationPath:target error:&err];
    //        msg = [NSString stringWithFormat:@"RESULT: %hhd, ERROR: %@", result, err];
    //        NSLog(msg);
    NSString *msg;
    NSDictionary *errorInfo;
    command = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", command];
    command = [NSString stringWithFormat:@"%@", command];
    [[[NSAppleScript alloc]initWithSource:command] executeAndReturnError:&errorInfo];
    if (errorInfo != nil) {
        return errorInfo;
    }
    return nil;
}


NSString *getEnvVar(NSString *var) {
    // Get environment variables as per var argument.
    NSString *path = [[[NSProcessInfo processInfo]environment]objectForKey:var];
    return path;
}


/********************
 END Useful Methods
 ********************/


- (void)showStatus:(enum kaliteStatus)status {
    // Enable/disable menu items based on status.
    BOOL canStart = pathExists(getUsrBinKalite()) > 0 ? YES : NO;
    switch (status) {
        case statusFailedToStart:
            [self.startKalite setEnabled:canStart];
            [self.stopKalite setEnabled:NO];
            self.startButton.enabled = canStart;
            self.stopButton.enabled = NO;
            self.openBrowserButton.enabled = NO;
            [self.openInBrowserMenu setEnabled:NO];
            [self.statusItem setImage:[NSImage imageNamed:@"exclaim"]];
            [self.statusItem setToolTip:@"KA-Lite failed to start."];
            break;
        case statusStartingUp:
            [self.startKalite setEnabled:NO];
            [self.stopKalite setEnabled:NO];
            [self.openInBrowserMenu setEnabled:NO];
            self.startButton.enabled = NO;
            self.stopButton.enabled = NO;
            self.openBrowserButton.enabled = NO;
            [self.statusItem setToolTip:@"KA-Lite is starting..."];
            break;
        case statusOkRunning:
            [self.startKalite setEnabled:NO];
            [self.stopKalite setEnabled:YES];
            [self.openInBrowserMenu setEnabled:YES];
            self.startButton.enabled = NO;
            self.stopButton.enabled = YES;
            self.openBrowserButton.enabled = YES;
            [self.statusItem setImage:[NSImage imageNamed:@"stop"]];
            [self.statusItem setToolTip:@"KA-Lite is running."];
            showNotification(@"You can now click on 'Open in Browser' menu");
            break;
        case statusStopped:
            [self.startKalite setEnabled:canStart];
            [self.stopKalite setEnabled:NO];
            [self.openInBrowserMenu setEnabled:NO];
            self.startButton.enabled = canStart;
            self.stopButton.enabled = NO;
            self.openBrowserButton.enabled = NO;
            [self.statusItem setImage:[NSImage imageNamed:@"favicon"]];
            [self.statusItem setToolTip:@"KA-Lite is stopped."];
            showNotification(@"Stopped");
            break;
        default:
            [self.startKalite setEnabled:canStart];
            [self.stopKalite setEnabled:NO];
            [self.openInBrowserMenu setEnabled:NO];
            self.startButton.enabled = canStart;
            self.stopButton.enabled = NO;
            self.openBrowserButton.enabled = NO;
            if (kaliteExists()){
                [self.statusItem setImage:[NSImage imageNamed:@"favicon"]];
            }else{
                [self.statusItem setImage:[NSImage imageNamed:@"exclaim"]];
            }
//            [self.statusItem setToolTip:@"KA-Lite has encountered an error, pls check the Console."];
//            showNotification(@"Has encountered an error, pls check the Console.");
            break;
    }
}


- (void)startFunction {
    showNotification(@"Starting...");
    [self showStatus:statusStartingUp];
    if (self.processCounter != 0) {
        alert(@"KA Lite is still processing, please wait until it is finished.");
        return;
    }
    [self runKalite:@"start"];
}


- (IBAction)start:(id)sender {
    [self startFunction];
}


- (IBAction)startButton:(id)sender {
    [self startFunction];
}


- (void)stopFunction {
    showNotification(@"Stopping...");
    if (self.processCounter != 0) {
        alert(@"KA Lite is still processing, please wait until it is finished.");
        return;
    }
    [self runKalite:@"stop"];
}


- (IBAction)stop:(id)sender {
    [self stopFunction];
}


- (IBAction)stopButton:(id)sender {
    [self stopFunction];
}


- (void)openFunction {
    // TODO(cpauya): Get the ip address and port from `local_settings.py` or preferences.
    // REF: http://stackoverflow.com/a/7129543/845481
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8008/"];
    if( ![[NSWorkspace sharedWorkspace] openURL:url] ) {
        NSString *msg = [NSString stringWithFormat:@" Failed to open url: %@",[url description]];
        showNotification(msg);
    }
}


- (IBAction)open:(id)sender {
    [self openFunction];
}


- (IBAction)openButton:(id)sender {
    [self openFunction];
}


- (IBAction)closeSplash:(id)sender {
    [self closeSplash];
}


- (IBAction)showPreferences:(id)sender {
    [self showPreferences];
    
}


- (IBAction)hidePreferences:(id)sender {
    [window orderOut:[window identifier]];
}


- (IBAction)savePreferences:(id)sender {
    [self savePreferences];
}


- (IBAction)discardPreferences:(id)sender {
    [self discardPreferences];
}


- (IBAction)extractAssessment:(id)sender {
    NSString *message = @"It will take a few seconds to extract assessment items. Do you want to continue?";
    if (self.processCounter != 0) {
        alert(@"KA Lite is still processing, please wait until it is finished.");
        return;
    }
}


- (IBAction)setupAction:(id)sender {
    if (kaliteExists()) {
        NSString *message = @"Are you sure you want to run setup?  This will take a few minutes to complete.";
        if (self.processCounter != 0) {
            alert(@"KA Lite is still processing, please wait until it is finished.");
            return;
        }
        if (confirm(message)) {
            [self setupKalite];
        }
    } else {
        alert(@"Sorry but the `kalite` executable was not found!");
    }
}


- (IBAction)resetAppAction:(id)sender {
    if (self.processCounter != 0) {
        alert(@"KA Lite is still processing, please wait until it is finished.");
        return;
    }
}


- (void)closeSplash {
    [splash orderOut:self];
}


- (void)showPreferences {
    [splash orderOut:self];
//    [self loadPreferences];
    [window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    //REF http://stackoverflow.com/questions/6994541/cocoa-showing-a-window-on-top-without-giving-it-focus
    [window setLevel:NSFloatingWindowLevel];
}


//- (void)loadPreferences {
    // TODO(amodia): Set custom database path in the preferences menu.
//}


- (void)savePreferences {
    /*
     1. Save the preferences: REF: http://stackoverflow.com/questions/10148788/xcode-cocoa-app-preferences
     2. Run `kalite manage setup` if no database was found.
     */
    
/*
    //TODO(amodia): Comment this to be reference for setting a custom database path in the preferences menu.
    NSString *username = self.stringUsername.stringValue;
    NSString *password = self.stringPassword.stringValue;
    NSString *confirmPassword = self.stringConfirmPassword.stringValue;
    
    self.username = username;
    self.password = password;
    self.confirmPassword = confirmPassword;
    
    if (self.processCounter != 0) {
        alert(@"KA Lite is still processing, please wait until it is finished.");
        return;
    }
    
    if (self.username == nil || [self.username isEqualToString:@""]) {
        alert(@"Username must not be blank and can only contain letters, numbers and @/./+/-/_ characters.");
        return;
    }
    
    NSString *usernameChars = getUsernameChars();
    if ([self string:usernameChars containsAllCharactersInString:self.username] == NO) {
        alert(@"Invalid username characters found, please use letters, numbers and @/./+/-/_ characters.");
        return;
    }
    
    if ([self.username length] > 30) {
        alert(@"Username must not exceed 30 characters.");
        return;
    }
    
    if (self.password == nil || [self.password isEqualToString:@""]) {
        alert(@"Invalid password or the password does not match on both fields.");
        return;
    }
    
    if (![self.password isEqualToString:self.confirmPassword]) {
        alert(@"The password does not match on both fields.");
        return;
    }
    
    if ([self.password length] > 128) {
        alert(@"Password must not exceed 128 characters.");
        return;
    }
 
    
    // Save the preferences.
    // REF: http://iosdevelopertips.com/core-services/encode-decode-using-base64.html
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    // TO set an object in NSUserDefaults use this sample "[prefs setObject:self.sample forKey:@"sample"];"
    // REF: https://github.com/iwasrobbed/Objective-C-CheatSheet#storing-values
    [prefs synchronize];
*/
    
    
    // Automatically run `kalite manage setup` if no database was found.
    NSString *databasePath = getDatabasePath();
    if (!pathExists(databasePath)) {
        if (checkUsrBinKalitePath()) {
            alert(@"Will now run KA-Lite setup, it will take a few minutes.  Please wait until prompted that setup is done.");
            enum kaliteStatus status = [self setupKalite];
            showNotification(@"Setup is finished!  You can now start KA-Lite.");
            [self.statusItem setImage:[NSImage imageNamed:@"exclaim"]];
            // TODO(cpauya): Get the result of running `bin/kalite manage setup` not the
            // default result of `bin/kalite status` so we can alert the user that setup failed.
            //        if (status != statusStopped) {
            //            alert(@"Running 'manage setup' failed, please see Console.");
            //            return;
            //        }
        }
    }
    
    // Close the preferences dialog after successful save.
    [window orderOut:[window identifier]];
}


-(enum kaliteStatus)setupKalite {
    NSString *cmd = [NSString stringWithFormat:@"manage setup --noinput"];
    NSString *msg = [NSString stringWithFormat:@"Running `kalite manage setup`"];
    showNotification(msg);
    enum kaliteStatus status = [self runKalite:cmd];
    [self getKaliteStatus];
    return status;
}


- (void)discardPreferences {
    // TODO(cpauya): Discard changes and load the saved preferences.
    [window orderOut:[window identifier]];
}


- (void)startKaliteTimer {
    // TODO(cpauya): Use initWithFireDate of NSTimer instance.
    [NSTimer scheduledTimerWithTimeInterval:60.0
                                    target:self
                                    selector:@selector(getKaliteStatus)
                                    userInfo:nil
                                    repeats:YES];
}


- (enum kaliteStatus)getKaliteStatus {
    return [self runKalite:@"status"];
}


@end

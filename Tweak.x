#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSUserDefaults+Private.h>
#import <dlfcn.h>

// Hey Siri, define laziness
typedef void (*EKHookFunction_t)(void *, void *, void **);
static EKHookFunction_t ElleKitHook = NULL;

// Log shortcut. Wow. 
#define LOG(fmt, ...) NSLog(@"[Solaria] " fmt, ##__VA_ARGS__)

// All of these are for preferences
static NSString * const tweakDomain = @"cc.forcequit.solaria";
static NSString * const tweakNotificationListener = @"cc.forcequit.solaria/preferences.changed";
static bool enabled = YES;
static bool allowUnsupported = NO;
static bool allowOptedOut = NO;

static bool hooked = false; // Tracks if the hook's already been installed
static bool (*original)(void); // Original function pointer

// Checks that Solaria's enabled, gets values for the incoming global UserDefaults writing
static void updatePreferences(void) {
    NSNumber *enabledValue = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"enabled" inDomain:tweakDomain];
    if (enabledValue != nil) {
        enabled = [enabledValue boolValue];
    }
    
    NSNumber *allowUnsupportedValue = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"allowUnsupported" inDomain:tweakDomain];
    if (allowUnsupportedValue != nil) {
        allowUnsupported = [allowUnsupportedValue boolValue];
    }
    
    NSNumber *allowOptedOutValue = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"allowOptedOut" inDomain:tweakDomain];
    if (allowOptedOutValue != nil) {
        allowOptedOut = [allowOptedOutValue boolValue];
    }
}

// Notification callback
static void notificationCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    updatePreferences();
    LOG(@"Preferences modified!");
}

// Writes values for Apple's SwiftUICore overrides to the global domain to match the values I have for Solaria's UserDefaults keys
static void applyPreferenceOverrides(void) {
    CFPreferencesSetValue(CFSTR("com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck"),
                          allowUnsupported ? kCFBooleanTrue : NULL,
                          kCFPreferencesAnyApplication,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesAnyHost);
    
    CFPreferencesSetValue(CFSTR("com.apple.SwiftUI.IgnoreSolariumOptOut"),
                          allowOptedOut ? kCFBooleanTrue : NULL,
                          kCFPreferencesAnyApplication,
                          kCFPreferencesCurrentUser,
                          kCFPreferencesAnyHost);
    
    CFPreferencesSynchronize(kCFPreferencesAnyApplication,
                            kCFPreferencesCurrentUser,
                            kCFPreferencesAnyHost);
}

// Loads ElleKit's EKHookFunction method manually (This is horrible and you probably should not ever do this but I was too lazy to just add a header or whatever)
// This was originally just a part of the install() function, but modularizing it made more sense during development when I was trying different hooks for extra stuff
static void loadElleKit(void) {
	if (ElleKitHook) return;
    dlopen("/usr/lib/libellekit.dylib", RTLD_NOW);
    ElleKitHook = (EKHookFunction_t)dlsym(RTLD_DEFAULT, "EKHookFunction");
    if (ElleKitHook) {
    	LOG(@"Loaded ElleKit successfully!");
    } else {
    	LOG(@"Failed to load ElleKit (what?)");
    }
}

// My replacement function that literally just returns true.
static bool replacement(void) {
    return true;
}

// Attempts to install hook to replace original function
static void install(void) {
	// Skip if we've hooked already
    if (hooked) return;
    // Skip if tweak's disabled
    if (!enabled) return;
	
	loadElleKit();
	
	// Verifies we have the symbol loaded
    void *symbol = dlsym(RTLD_DEFAULT, "_CUIAppleTVDeviceSupportsSolarium");
    if (!symbol) {
    	LOG(@"Unable to find symbol to patch Solarium support.");
        return;
    }
	
	// Actual hook that replaces function
    ElleKitHook(symbol, (void *)replacement, (void **)&original);
    hooked = true;
    LOG(@"WE OUTSIDE!!! #A10XGANG #A8GANG");
}

%ctor {
    // Updates preferences
    updatePreferences();
    applyPreferenceOverrides();
	
    // Notification listener thing I think for when preferences are modified
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    notificationCallback,
                                    (CFStringRef)tweakNotificationListener,
                                    NULL,
                                    CFNotificationSuspensionBehaviorCoalesce);
	// Installs the hook!
    install();
}
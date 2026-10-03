#import "WFAppDelegate.h"
#import "WFEventFilter.h"

static NSString *const WFEnabledKey = @"filterEnabled";
static NSString *const WFDebounceKey = @"debounceMilliseconds";
static NSString *const WFTargetsKey = @"targetApplications";

@implementation WFAppDelegate {
    NSStatusItem *_statusItem;
    NSMenu *_menu;
    WFEventFilter *_eventFilter;
    NSUserDefaults *_defaults;
    NSRunningApplication *_lastExternalApplication;
    NSTimer *_permissionTimer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    // Keep settings in the application's standard preferences domain.
    _defaults = NSUserDefaults.standardUserDefaults;
    NSCAssert(_defaults != nil, @"Wheel Filter preferences must be available");
    [_defaults registerDefaults:@{
        WFEnabledKey: @YES,
        WFDebounceKey: @50,
        WFTargetsKey: @{},
    }];
    _eventFilter = [[WFEventFilter alloc] init];

    [self rememberExternalApplication:NSWorkspace.sharedWorkspace.frontmostApplication];

    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    _statusItem.button.image = [NSImage imageWithSystemSymbolName:@"computermouse"
                                         accessibilityDescription:@"Wheel Filter"];
    _statusItem.button.toolTip = @"Wheel Filter";

    _menu = [[NSMenu alloc] init];
    _menu.delegate = self;
    _statusItem.menu = _menu;

    [NSWorkspace.sharedWorkspace.notificationCenter
        addObserver:self
        selector:@selector(applicationActivated:)
        name:NSWorkspaceDidActivateApplicationNotification
        object:nil];

    [self requestAccessibilityPermissionIfNeeded];
    [self refreshPermissionAndTap];
    [self refreshFilteringState];

    _permissionTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
        target:self
        selector:@selector(periodicRefresh:)
        userInfo:nil
        repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [_permissionTimer invalidate];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [_eventFilter stop];
}

- (void)menuWillOpen:(NSMenu *)menu {
    [self rememberExternalApplication:NSWorkspace.sharedWorkspace.frontmostApplication];
    [self refreshPermissionAndTap];
    [self refreshFilteringState];
    [self rebuildMenu];
}

- (void)applicationActivated:(NSNotification *)notification {
    NSRunningApplication *application = notification.userInfo[NSWorkspaceApplicationKey];
    [self rememberExternalApplication:application];
    [self refreshFilteringState];
}

- (void)periodicRefresh:(NSTimer *)timer {
    [self refreshPermissionAndTap];
    [self refreshFilteringState];
}

- (void)rememberExternalApplication:(NSRunningApplication *)application {
    if (application != nil && application.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
        _lastExternalApplication = application;
    }
}

- (NSRunningApplication *)currentApplication {
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (frontmost != nil && frontmost.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
        return frontmost;
    }
    return _lastExternalApplication;
}

- (NSString *)currentBundleIdentifier {
    return self.currentApplication.bundleIdentifier;
}

- (NSString *)currentApplicationName {
    return self.currentApplication.localizedName ?: @"Unknown";
}

- (BOOL)masterEnabled {
    return [_defaults boolForKey:WFEnabledKey];
}

- (NSInteger)debounceMilliseconds {
    NSInteger value = [_defaults integerForKey:WFDebounceKey];
    return [@[@30, @40, @50, @75] containsObject:@(value)] ? value : 50;
}

- (NSDictionary<NSString *, NSString *> *)targetApplications {
    NSDictionary *value = [_defaults dictionaryForKey:WFTargetsKey];
    return value ?: @{};
}

- (BOOL)isCurrentApplicationTargeted {
    NSString *bundleIdentifier = self.currentBundleIdentifier;
    return bundleIdentifier != nil && self.targetApplications[bundleIdentifier] != nil;
}

- (BOOL)accessibilityGranted {
    return AXIsProcessTrusted();
}

- (BOOL)filteringActive {
    return self.masterEnabled
        && self.accessibilityGranted
        && _eventFilter.running
        && self.isCurrentApplicationTargeted;
}

- (void)requestAccessibilityPermissionIfNeeded {
    if (self.accessibilityGranted) {
        return;
    }
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)refreshPermissionAndTap {
    if (self.accessibilityGranted) {
        [_eventFilter start];
    } else if (_eventFilter.running) {
        [_eventFilter stop];
    }
}

- (void)refreshFilteringState {
    [_eventFilter updateActive:self.filteringActive
        debounceInterval:(NSTimeInterval)self.debounceMilliseconds / 1000.0];

    BOOL active = self.filteringActive;
    NSString *symbol = active ? @"computermouse.fill" : @"computermouse";
    NSString *tooltip = active
        ? [NSString stringWithFormat:@"Wheel Filter: filtering %@", self.currentApplicationName]
        : @"Wheel Filter: not filtering";
    _statusItem.button.image = [NSImage imageWithSystemSymbolName:symbol
                                          accessibilityDescription:tooltip];
    _statusItem.button.toolTip = tooltip;
}

- (NSMenuItem *)itemWithTitle:(NSString *)title action:(SEL)action {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    return item;
}

- (void)rebuildMenu {
    [_menu removeAllItems];

    NSMenuItem *appItem = [[NSMenuItem alloc]
        initWithTitle:[NSString stringWithFormat:@"Front app: %@", self.currentApplicationName]
        action:nil
        keyEquivalent:@""];
    appItem.enabled = NO;
    [_menu addItem:appItem];

    NSString *statusText;
    if (!self.accessibilityGranted) {
        statusText = @"Filter: Accessibility permission required";
    } else if (!_eventFilter.running) {
        statusText = @"Filter: Event tap unavailable";
    } else if (!self.masterEnabled) {
        statusText = @"Filter: Off";
    } else if (self.filteringActive) {
        statusText = [NSString stringWithFormat:@"Filter: Active (%ld ms)", self.debounceMilliseconds];
    } else if (self.targetApplications.count == 0) {
        statusText = @"Filter: Waiting for a game to be added";
    } else {
        statusText = @"Filter: Standby";
    }
    NSMenuItem *stateItem = [[NSMenuItem alloc] initWithTitle:statusText action:nil keyEquivalent:@""];
    stateItem.enabled = NO;
    [_menu addItem:stateItem];
    [_menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *enabledItem = [self itemWithTitle:@"Enable Wheel Filter" action:@selector(toggleMasterEnabled:)];
    enabledItem.state = self.masterEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [_menu addItem:enabledItem];

    NSMenuItem *thresholdItem = [[NSMenuItem alloc] initWithTitle:@"Debounce" action:nil keyEquivalent:@""];
    NSMenu *thresholdMenu = [[NSMenu alloc] init];
    for (NSNumber *value in @[@30, @40, @50, @75]) {
        NSMenuItem *item = [self itemWithTitle:[NSString stringWithFormat:@"%@ ms", value]
            action:@selector(selectThreshold:)];
        item.tag = value.integerValue;
        item.state = self.debounceMilliseconds == value.integerValue
            ? NSControlStateValueOn
            : NSControlStateValueOff;
        [thresholdMenu addItem:item];
    }
    thresholdItem.submenu = thresholdMenu;
    [_menu addItem:thresholdItem];
    [_menu addItem:NSMenuItem.separatorItem];

    NSString *targetTitle = self.isCurrentApplicationTargeted
        ? [NSString stringWithFormat:@"Filter This App: %@", self.currentApplicationName]
        : [NSString stringWithFormat:@"Add This App as a Game: %@", self.currentApplicationName];
    NSMenuItem *targetItem = [self itemWithTitle:targetTitle action:@selector(toggleCurrentApplicationTarget:)];
    targetItem.state = self.isCurrentApplicationTargeted ? NSControlStateValueOn : NSControlStateValueOff;
    targetItem.enabled = self.currentBundleIdentifier != nil;
    [_menu addItem:targetItem];

    NSMenuItem *gamesItem = [[NSMenuItem alloc] initWithTitle:@"Configured Games" action:nil keyEquivalent:@""];
    gamesItem.submenu = [self configuredGamesMenu];
    [_menu addItem:gamesItem];

    if (!self.accessibilityGranted || !_eventFilter.running) {
        [_menu addItem:NSMenuItem.separatorItem];
        [_menu addItem:[self itemWithTitle:@"Grant Accessibility Permission…"
            action:@selector(openAccessibilitySettings:)]];
        [_menu addItem:[self itemWithTitle:@"Retry Event Tap"
            action:@selector(retryEventTap:)]];
    }

    [_menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Wheel Filter"
        action:@selector(quit:)
        keyEquivalent:@"q"];
    quitItem.target = self;
    [_menu addItem:quitItem];
}

- (NSMenu *)configuredGamesMenu {
    NSMenu *gamesMenu = [[NSMenu alloc] init];
    NSDictionary<NSString *, NSString *> *applications = self.targetApplications;
    NSArray<NSString *> *bundleIdentifiers = [applications keysSortedByValueUsingComparator:
        ^NSComparisonResult(NSString *first, NSString *second) {
            return [first localizedCaseInsensitiveCompare:second];
        }];

    if (bundleIdentifiers.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc] initWithTitle:@"No games added" action:nil keyEquivalent:@""];
        emptyItem.enabled = NO;
        [gamesMenu addItem:emptyItem];
        return gamesMenu;
    }

    for (NSString *bundleIdentifier in bundleIdentifiers) {
        NSString *name = applications[bundleIdentifier];
        NSMenuItem *item = [self itemWithTitle:[NSString stringWithFormat:@"Remove %@", name]
            action:@selector(removeConfiguredApplication:)];
        item.representedObject = bundleIdentifier;
        [gamesMenu addItem:item];
    }
    return gamesMenu;
}

- (void)toggleMasterEnabled:(id)sender {
    [_defaults setBool:!self.masterEnabled forKey:WFEnabledKey];
    [self refreshFilteringState];
}

- (void)selectThreshold:(NSMenuItem *)sender {
    [_defaults setInteger:sender.tag forKey:WFDebounceKey];
    [self refreshFilteringState];
}

- (void)toggleCurrentApplicationTarget:(id)sender {
    NSString *bundleIdentifier = self.currentBundleIdentifier;
    if (bundleIdentifier == nil) {
        return;
    }

    NSMutableDictionary *applications = [self.targetApplications mutableCopy];
    if (applications[bundleIdentifier] != nil) {
        [applications removeObjectForKey:bundleIdentifier];
    } else {
        applications[bundleIdentifier] = self.currentApplicationName;
    }
    [_defaults setObject:applications forKey:WFTargetsKey];
    [self refreshFilteringState];
}

- (void)removeConfiguredApplication:(NSMenuItem *)sender {
    NSString *bundleIdentifier = sender.representedObject;
    if (![bundleIdentifier isKindOfClass:NSString.class]) {
        return;
    }
    NSMutableDictionary *applications = [self.targetApplications mutableCopy];
    [applications removeObjectForKey:bundleIdentifier];
    [_defaults setObject:applications forKey:WFTargetsKey];
    [self refreshFilteringState];
}

- (void)retryEventTap:(id)sender {
    [self requestAccessibilityPermissionIfNeeded];
    [_eventFilter stop];
    [self refreshPermissionAndTap];
    [self refreshFilteringState];
}

- (void)openAccessibilitySettings:(id)sender {
    [self requestAccessibilityPermissionIfNeeded];
    NSURL *url = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    if (url != nil) {
        [NSWorkspace.sharedWorkspace openURL:url];
    }
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

@end


#import "WFAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        WFAppDelegate *delegate = [[WFAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}

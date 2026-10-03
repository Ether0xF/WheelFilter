#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>

// Owns the scroll event tap; inactive filters return every event unchanged.
@interface WFEventFilter : NSObject
@property(nonatomic, readonly) BOOL running;
- (void)updateActive:(BOOL)active debounceInterval:(NSTimeInterval)interval;
- (BOOL)start;
- (void)stop;
@end

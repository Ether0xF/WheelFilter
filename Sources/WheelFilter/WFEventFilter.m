#import "WFEventFilter.h"
#import "WheelDebouncer.h"

static CGEventRef WFEventTapCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *userInfo
);

@interface WFEventFilter ()
- (void)reenable;
- (CGEventRef)handleEvent:(CGEventRef)event;
@end

@implementation WFEventFilter {
    NSLock *_lock;
    WFDebouncer _debouncer;
    BOOL _active;
    NSTimeInterval _debounceInterval;
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _debounceInterval = 0.050;
        WFDebouncerReset(&_debouncer);
    }
    return self;
}

- (BOOL)running {
    return _eventTap != NULL;
}

- (void)updateActive:(BOOL)active debounceInterval:(NSTimeInterval)interval {
    [_lock lock];
    if (_active != active || _debounceInterval != interval) {
        WFDebouncerReset(&_debouncer);
    }
    _active = active;
    _debounceInterval = interval;
    [_lock unlock];
}

- (CGEventRef)handleEvent:(CGEventRef)event {
    [_lock lock];
    if (!_active) {
        [_lock unlock];
        return event;
    }

    int64_t delta = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
    WFDecision decision = WFDebouncerDecide(
        &_debouncer,
        delta,
        NSProcessInfo.processInfo.systemUptime,
        _debounceInterval
    );
    [_lock unlock];

    // Passing returns the original CGEvent unchanged. No delta field is rewritten.
    return decision == WFDecisionPass ? event : NULL;
}

- (BOOL)start {
    if (_eventTap != NULL) {
        return YES;
    }

    CGEventMask mask = CGEventMaskBit(kCGEventScrollWheel);
    _eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        WFEventTapCallback,
        (__bridge void *)self
    );
    if (_eventTap == NULL) {
        return NO;
    }

    _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (_runLoopSource == NULL) {
        CFMachPortInvalidate(_eventTap);
        CFRelease(_eventTap);
        _eventTap = NULL;
        return NO;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(_eventTap, true);
    return YES;
}

- (void)stop {
    if (_runLoopSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CFRelease(_runLoopSource);
        _runLoopSource = NULL;
    }
    if (_eventTap != NULL) {
        CFMachPortInvalidate(_eventTap);
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
}

- (void)reenable {
    if (_eventTap != NULL) {
        CGEventTapEnable(_eventTap, true);
    }
}

- (void)dealloc {
    [self stop];
}

@end

static CGEventRef WFEventTapCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *userInfo
) {
    (void)proxy;
    WFEventFilter *filter = (__bridge WFEventFilter *)userInfo;

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        [filter reenable];
        return event;
    }
    if (type != kCGEventScrollWheel) {
        return event;
    }
    return [filter handleEvent:event];
}


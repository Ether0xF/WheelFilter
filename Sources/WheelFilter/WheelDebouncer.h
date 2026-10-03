#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WFDecision) {
    WFDecisionPass,
    WFDecisionBlockTail,
    WFDecisionBlockDebounced,
};

typedef struct {
    NSTimeInterval lastPassedTime;
    int64_t lastDirection;
} WFDebouncer;

FOUNDATION_EXPORT void WFDebouncerReset(WFDebouncer *debouncer);

// delta is the vertical line delta; now and interval are in seconds.
// Only passed events advance the time window. Direction changes pass immediately.
FOUNDATION_EXPORT WFDecision WFDebouncerDecide(
    WFDebouncer *debouncer,
    int64_t delta,
    NSTimeInterval now,
    NSTimeInterval interval
);

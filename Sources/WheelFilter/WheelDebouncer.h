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

FOUNDATION_EXPORT WFDecision WFDebouncerDecide(
    WFDebouncer *debouncer,
    int64_t delta,
    NSTimeInterval now,
    NSTimeInterval interval
);

#import "WheelDebouncer.h"

void WFDebouncerReset(WFDebouncer *debouncer) {
    debouncer->lastPassedTime = 0;
    debouncer->lastDirection = 0;
}

WFDecision WFDebouncerDecide(
    WFDebouncer *debouncer,
    int64_t delta,
    NSTimeInterval now,
    NSTimeInterval interval
) {
    if (delta == 0) {
        return WFDecisionBlockTail;
    }

    int64_t direction = delta > 0 ? 1 : -1;
    if (direction != debouncer->lastDirection) {
        debouncer->lastDirection = direction;
        debouncer->lastPassedTime = now;
        return WFDecisionPass;
    }

    if (now - debouncer->lastPassedTime < interval) {
        return WFDecisionBlockDebounced;
    }

    debouncer->lastPassedTime = now;
    return WFDecisionPass;
}

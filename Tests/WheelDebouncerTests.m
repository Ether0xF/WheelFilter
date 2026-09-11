#import <Foundation/Foundation.h>
#import <assert.h>
#import "WheelDebouncer.h"

int main(void) {
    @autoreleasepool {
        WFDebouncer debouncer;
        WFDebouncerReset(&debouncer);

        assert(WFDebouncerDecide(&debouncer, 0, 10.000, 0.050) == WFDecisionBlockTail);
        assert(WFDebouncerDecide(&debouncer, 3, 10.000, 0.050) == WFDecisionPass);
        assert(WFDebouncerDecide(&debouncer, 1, 10.020, 0.050) == WFDecisionBlockDebounced);
        assert(WFDebouncerDecide(&debouncer, 4, 10.049, 0.050) == WFDecisionBlockDebounced);
        assert(WFDebouncerDecide(&debouncer, 2, 10.051, 0.050) == WFDecisionPass);

        assert(WFDebouncerDecide(&debouncer, -1, 10.052, 0.050) == WFDecisionPass);
        assert(WFDebouncerDecide(&debouncer, -2, 10.060, 0.050) == WFDecisionBlockDebounced);
        assert(WFDebouncerDecide(&debouncer, 1, 10.061, 0.050) == WFDecisionPass);

        WFDebouncerReset(&debouncer);
        assert(WFDebouncerDecide(&debouncer, 1, 10.062, 0.050) == WFDecisionPass);
        NSLog(@"WheelDebouncer tests passed");
    }
    return 0;
}

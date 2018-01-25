//
//  YSpanContext.m
//  LightStepTestUI
//
//  Created by Ben Sigelman on 7/21/16.
//  Copyright © 2016 LightStep. All rights reserved.
//

#import "YSpanContext.h"
#import "YUtil.h"

@implementation YSpanContext

- (instancetype)initWithTraceId:(NSString*)traceId spanId:(NSString*)spanId baggage:(nullable NSDictionary *)baggage {
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
        _baggage = baggage ?: @{};
    }
    return self;
}

- (YSpanContext *)withBaggageItem:(NSString *)key value:(NSString *)value {
    NSMutableDictionary *baggageCopy = [self.baggage mutableCopy];
    [baggageCopy setObject:value forKey:key];
    return [[YSpanContext alloc] initWithTraceId:self.traceId spanId:self.spanId baggage:baggageCopy];
}

- (NSString *)baggageItemForKey:(NSString *)key {
    return (NSString *)[self.baggage objectForKey:key];
}

- (void)forEachBaggageItem:(BOOL (^)(NSString *key, NSString *value))callback {
    for (NSString *key in self.baggage) {
        if (!callback(key, [self.baggage objectForKey:key])) {
            return;
        }
    }
}

- (NSString *)hexTraceId {
    return self.traceId;
//    return [YUtil hexGUID:self.traceId];
}

- (NSString *)hexSpanId {
    return self.spanId;
//    return [YUtil hexGUID:self.spanId];
}

@end

//
//  YSpanContext.h
//  LightStepTestUI
//
//  Created by Ben Sigelman on 7/21/16.
//  Copyright © 2016 LightStep. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <opentracing/OTSpanContext.h>

NS_ASSUME_NONNULL_BEGIN

@interface YSpanContext : NSObject<OTSpanContext>

#pragma mark - LightStep API

- (instancetype)initWithTraceId:(NSString*)traceId spanId:(NSString*)spanId baggage:(nullable NSDictionary *)baggage;

/// Return a copy of this SpanContext with the given (potentially additional) baggage item.
- (YSpanContext *)withBaggageItem:(NSString *)key value:(NSString *)value;

/// Return a specific baggage item.
- (NSString *)baggageItemForKey:(NSString *)key;

/// The LightStep Span's probabilistically unique trace id.
@property(nonatomic) NSString* traceId;

/// The LightStep Span's probabilistically unique (span) id.
@property(nonatomic) NSString* spanId;

/// The trace id as a hexadecimal string.
- (NSString *)hexTraceId;

/// The span id as a hexadecimal string.
- (NSString *)hexSpanId;

#pragma mark - Internal

/// The baggage dictionary (for internal use only).
@property(nonatomic, strong, readonly) NSDictionary *baggage;

@end

NS_ASSUME_NONNULL_END

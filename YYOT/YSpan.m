#import "YSpan.h"
#import "YSpanContext.h"
#import "YTracer.h"
#import "YUtil.h"
#import <opentracing/OTReference.h>

#pragma mark - YLog

@interface YLog : NSObject

@property(nonatomic, strong, readonly) NSDate *timestamp;
@property(nonatomic, strong, readonly) NSDictionary<NSString *, NSObject *> *fields;

- (instancetype)initWithTimestamp:(NSDate *)timestamp fields:(NSDictionary<NSString *, NSObject *> *)fields;

@end

@implementation YLog

- (instancetype)initWithTimestamp:(NSDate *)timestamp fields:(NSDictionary<NSString *, NSObject *> *)fields {
    if (self = [super init]) {
        _timestamp = timestamp;
        _fields = [NSDictionary dictionaryWithDictionary:fields];
    }
    return self;
}

- (NSDictionary *)toJSONWithMaxPayloadLength:(NSUInteger)maxPayloadJSONLength {
    NSMutableDictionary<NSString *, NSObject *> *outputFields = @{}.mutableCopy;
    outputFields[@"timestamp"] = @([self.timestamp toMicros]);
    if (self.fields.count > 0) {
//        outputFields[@"fields"] = [YUtil keyValueArrayFromDictionary:self.fields];
        [outputFields addEntriesFromDictionary:self.fields];
    }
    return outputFields;
}

@end

#pragma mark - YSpan

@interface YSpan ()
@property(nonatomic, strong) YSpanContext *parent;
@property(atomic, strong) NSString *operationName;
@property(atomic, strong) YSpanContext *context;
@property(nonatomic, strong) NSMutableArray<YLog *> *logs;
@property(atomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *mutableTags;
@property(atomic, strong) NSArray* references;
@end

@implementation YSpan

- (instancetype)initWithTracer:(YTracer *)client {
    return [self initWithTracer:client operationName:@"" references:nil tags:nil startTime:nil];
}

- (instancetype)initWithTracer:(YTracer *)tracer
                 operationName:(NSString *)operationName
                    references:(nullable NSArray<OTReference *>*)references
                          tags:(nullable NSDictionary *)tags
                     startTime:(nullable NSDate *)startTime {
    if (self = [super init]) {
        _tracer = tracer;
        _operationName = operationName;
        _startTime = startTime ?: [NSDate date];
        _logs = @[].mutableCopy;
        _mutableTags = @{}.mutableCopy;
//        _parent = parent;
        _references = references;
        NSMutableDictionary* baggage = [NSMutableDictionary new];
        NSString* traceId = nil;
        if( references.count )
        {
            for ( OTReference* ref in references ) {
                [ref.referencedContext forEachBaggageItem:^BOOL(NSString * _Nonnull key, NSString * _Nonnull value) {
                    [baggage setObject:value forKey:key];
                    return true;
                }];
            }
            traceId = ((YSpanContext*)references[0].referencedContext).traceId;
        }
        if ( traceId == nil )
        {
            traceId = [YUtil generateGUID];
        }
        NSString* spanId = [YUtil generateGUID];
        _context = [[YSpanContext alloc] initWithTraceId:traceId spanId:spanId baggage:baggage];

        [self addTags:tags];
    }
    return self;
}

- (NSDictionary<NSString *, NSString *> *)tags {
    return [self.mutableTags copy];
}

- (void)setTag:(NSString *)key value:(NSString *)value {
    [self.mutableTags setObject:value forKey:key];
}

- (void)logEvent:(NSString *)eventName {
    [self log:eventName timestamp:[NSDate date] payload:nil];
}

- (void)logEvent:(NSString *)eventName payload:(NSObject *)payload {
    [self log:eventName timestamp:[NSDate date] payload:payload];
}

- (void)log:(NSString *)eventName timestamp:(NSDate *)timestamp payload:(NSObject *)payload {
    // No locking is required as all the member variables used below are immutable
    // after initialization.

    if (!self.tracer.enabled) {
        return;
    }

    NSMutableDictionary<NSString *, NSObject *> *fields = [NSMutableDictionary<NSString *, NSObject *> dictionary];
    if (eventName != nil) {
        fields[@"event"] = eventName;
    }
    if (payload != nil) {
//        NSString *payloadJSON = [YUtil objectToJSONString:payload maxLength:[self.tracer maxPayloadJSONLength]];
        fields[@"value"] = payload;
    }
    [self _appendLog:[[YLog alloc] initWithTimestamp:timestamp fields:fields]];
}

- (void)log:(NSDictionary<NSString *, NSObject *> *)fields {
    [self log:fields timestamp:[NSDate date]];
}

- (void)log:(NSDictionary<NSString *, NSObject *> *)fields timestamp:(nullable NSDate *)timestamp {
    // No locking is required as all the member variables used below are immutable
    // after initialization.
    if (!self.tracer.enabled) {
        return;
    }
    [self _appendLog:[[YLog alloc] initWithTimestamp:timestamp fields:fields]];
}

- (void)_appendLog:(YLog *)log {
    [self.logs addObject:log];
}

- (void)finish {
    [self finishWithTime:[NSDate date]];
}

- (void)finishWithTime:(NSDate *)finishTime {
    if (finishTime == nil) {
        finishTime = [NSDate date];
    }

    NSDictionary *spanJSON;
    @synchronized(self) {
        spanJSON = [self _toJSONWithFinishTime:finishTime];
    }
    [self.tracer _appendSpanJSON:spanJSON];
}

- (id<OTSpan>)setBaggageItem:(NSString *)key value:(NSString *)value {
    // TODO: change selector in OTSpan.h to setBaggageItem:forKey:
    self.context = [self.context withBaggageItem:key value:value];
    return self;
}

- (NSString *)getBaggageItem:(NSString *)key {
    // TODO: rename selector in OTSpan.h to baggageItemForKey:
    return [self.context baggageItemForKey:key];
}

/// Add a set of tags from the given dictionary. Existing key-value pairs will be overwritten by any new tags.
- (void)addTags:(NSDictionary *)tags {
    if (tags == nil) {
        return;
    }
    [self.mutableTags addEntriesFromDictionary:tags];
}

- (NSString *)tagForKey:(NSString *)key {
    return (NSString *)[self.mutableTags objectForKey:key];
}

- (NSURL *)traceURL {
    int64_t now = [[NSDate date] toMicros];
    NSString *fmt = @"https://app.lightstep.com/%@/trace?span_guid=%@&at_micros=%@";
    NSString *accessToken = [[self.tracer accessToken] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *guid = [self.context.spanId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//        [[YUtil hexGUID:self.context.spanId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *urlStr = [NSString stringWithFormat:fmt, accessToken, guid, @(now)];
    return [NSURL URLWithString:urlStr];
}

/**
 * Generate a JSON-ready NSDictionary representation. Return value must not be
 * modified.
 */
- (NSDictionary *)_toJSONWithFinishTime:(NSDate *)finishTime {
    NSMutableArray<NSDictionary *> *logs = [NSMutableArray arrayWithCapacity:self.logs.count];
    for (YLog *l in self.logs) {
        [logs addObject:[l toJSONWithMaxPayloadLength:self.tracer.maxPayloadJSONLength]];
    }

//    NSMutableArray *attributes = [YUtil keyValueArrayFromDictionary:self.mutableTags];
//    if (self.parent != nil) {
//        [attributes addObject:@{ @"Key": @"parent_span_guid", @"Value": self.parent.hexSpanId }];
//    }

    // return value spec:
    // https://github.com/lightstep/lightstep-tracer-go/blob/40cbd138e6901f0dafdd0cccabb6fc7c5a716efb/lightstep_thrift/ttypes.go#L1247
    NSMutableDictionary<NSString*,NSObject*>* spanjsondic = [@{
        @"traceid": self.context.traceId,//hexTraceId,
        @"spanid": self.context.spanId,//hexSpanId,
        @"operationname": self.operationName,
        @"starttime": @([self.startTime toMicros]),
        @"duration": @([finishTime toMicros]-[self.startTime toMicros]),
//        @"attributes": attributes,
    } mutableCopy];
    if( logs.count )
    {
        spanjsondic[@"logs"] = logs;
    }
    if( self.mutableTags.count )
    {
        spanjsondic[@"tags"] = [self.mutableTags copy];
    }
    if( self.references.count )
    {
        NSMutableArray* refs = [NSMutableArray new];
        for ( OTReference* ref in refs ) {
            YSpanContext* context = (YSpanContext*)ref.referencedContext;
            [refs addObject:@{@"spanId":context.spanId,@"traceId":context.traceId,@"reftype":([ref.type isEqualToString:OTReferenceChildOf]?@"CHILD_OF":@"FOLLOWS_FROM")}];
        }
        spanjsondic[@"reference"] = refs;
    }
    return spanjsondic;
}

@end

#import <Foundation/Foundation.h>
#import <opentracing/OTSpan.h>
NS_ASSUME_NONNULL_BEGIN

@class YSpanContext;
@class YTracer;
@class OTReference;
/// An `YSpan` represents a logical unit of work done by the service.
/// One or more spans – presumably from different processes – are assembled into traces.
///
/// The YSpan class is thread-safe.
@interface YSpan : NSObject<OTSpan>


@property(nonatomic, strong, readonly) YTracer *tracer;

/// Internal function.
///
/// Creates a new span associated with the given tracer.
- (instancetype)initWithTracer:(YTracer *)tracer;

/// Internal function.
///
/// Creates a new span associated with the given tracer and the other optional parameters.
- (instancetype)initWithTracer:(YTracer *)tracer
                 operationName:(NSString *)operationName
                    references:(nullable NSArray<OTReference *>*)references
                          tags:(nullable NSDictionary *)tags
                     startTime:(nullable NSDate *)startTime;

@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *tags;

///  Get a particular tag.
- (NSString *)tagForKey:(NSString *)key;

/// Generate a URL to the trace containing this span on LightStep.
- (NSURL *)traceURL;

/// For testing only
- (NSDictionary *)_toJSONWithFinishTime:(NSDate *)finishTime;

@property(nonatomic, strong, readonly) NSDate *startTime;

@end
NS_ASSUME_NONNULL_END

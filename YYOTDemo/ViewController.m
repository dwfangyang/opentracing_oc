//
//  ViewController.m
//  YYOTDemo
//
//  Created by 方阳 on 2018/1/25.
//  Copyright © 2018年 yy. All rights reserved.
//

#import "ViewController.h"
#import "YTracer.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    YTracer* tracer = [[YTracer alloc] initWithToken:@"TOKEN"];
    id<OTSpan> parentspan = [tracer startSpan:@"button_pressed"];
    
    id<OTSpan> span = [tracer startSpan:@"request" childOf:parentspan.context];
    NSMutableDictionary* carrier = [NSMutableDictionary new];
    [tracer inject:span.context format:OTFormatTextMap carrier:carrier];
    [span logEvent:@"response" payload:[NSObject new]];
    [span finish];
    [parentspan logEvent:@"query_complete" payload:@{@"main_thread":@([NSThread isMainThread])}];
    [parentspan logEvent:@"ui_update" payload:@{@"main_thread":@([NSThread isMainThread])}];
    [parentspan finish];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

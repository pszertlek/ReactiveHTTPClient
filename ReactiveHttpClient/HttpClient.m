//
//  HttpClient.m
//  Motormaster
//
//  Created by Coco on 3/11/15.
//  Copyright (c) 2015 Hangzhou Xuanchao Technology Co. Ltd. All rights reserved.
//

#import "HttpClient.h"
#import "AFHTTPSessionManager+RACSupport.h"
#import <JSONModel.h>
#import <ReactiveCocoa.h>

NSString * const kTokenExpiresNotification = @"TokenExpires_Notification";
NSInteger TOKEN_EXPIRES_ERROR_CODE = -11111;
static NSString * const YXParserErrorDomain = @"YXParserErrorDomain";
static NSInteger const YXParserErrorJSONParsingFailed = 2000;
static NSInteger kLoginErrorCode = 20001;
static NSString *kSuccessKey = @"success";
static NSString *kCodeKey = @"code";
static NSString *kMessageKey = @"message";
static NSString *AppKey = @"1711394416800";
static NSString *AppSecret = @"cc1745453991ec29bfedd5f80a2d5bf0";
static NSString *const kTyreErrorDomain = @"com.coco.httperror";


// TODO need to modify
NSString * const kAppSecret = @"7vH7XZRjYMVyJfx7";

static dispatch_queue_t yx_httpClient_complete_queue() {
    static dispatch_queue_t httpClient_complete_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpClient_complete_queue = dispatch_queue_create("com.Motormaster.networking.session.manager.complete", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return httpClient_complete_queue;
}
@interface HttpClient ()

@end

@implementation HttpClient


+ (instancetype)sharedClient
{
    static id sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    
    return sharedClient;
}

- (instancetype)init
{
    NSString *string;
    self = [super initWithBaseURL:[NSURL URLWithString:string]];
    if (self) {
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSLog(@"\nRequest Header: %@",self.requestSerializer.HTTPRequestHeaders);
        AFJSONResponseSerializer *responseSerializer = [AFJSONResponseSerializer serializer];
        responseSerializer.removesKeysWithNullValues = YES;
        self.responseSerializer = responseSerializer;
        self.completionQueue = yx_httpClient_complete_queue();
        self.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    }
    
    return self;
}

#pragma mark - Private


- (NSMutableDictionary *)trimAllParams:(NSDictionary *)params
{
    if (!params) {
        return nil;
    }
    NSMutableDictionary *trimParams = [NSMutableDictionary dictionary];
    NSArray *allKeys = [params allKeys];
    for (NSInteger i = 0; i < [allKeys count]; i++) {
        NSString *key = [allKeys objectAtIndex:i];
        id value = [params objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *trimValue = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [trimParams setValue:trimValue forKey:key];
        } else {
            [trimParams setValue:value forKey:key];
        }
        
    }
    return trimParams;
}


- (NSURLSessionDataTask *)dataTaskWithHTTPMethod:(NSString *)method
                                       URLString:(NSString *)URLString
                                      parameters:(id)parameters
                                     resultBlock:(ResultBlock)resultBlock
{
    NSDictionary *signedParams = [self getFinialParameters:parameters];
    NSLog(@"%@ %@", method, [[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString]);
    NSLog(@"Params:\n%@", signedParams);
    NSError *serializationError = nil;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:[[NSURL URLWithString:URLString relativeToURL:self.baseURL] absoluteString] parameters:signedParams error:&serializationError];
    NSLog(@"%@",request);
    if (serializationError) {
        dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
            resultBlock(nil, serializationError);
        });
        return nil;
    }
    NSURLSessionDataTask *dataTask = [self dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        NSLog(@"\nRequestURL: %@", [request.URL absoluteString]);
        NSLog(@"\nResponseObject: %@", responseObject);
        if (error) {
            NSLog(@"Request Failed: %@", error);
            NSString *errorMessage = @"网络链接有问题，请检查网络设置.";
            if (((NSHTTPURLResponse *)(response)).statusCode > 299) {
                errorMessage = @"网络好像不太通畅，请稍候再试哦";
            }
            error = [NSError errorWithDomain:kTyreErrorDomain code:error.code userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
            if (resultBlock) {
                resultBlock(nil,error);
            }
        }
        else{
            if ([responseObject isKindOfClass:[NSDictionary class]] == NO) {
                responseObject = nil;
            }
            BOOL isSuccess = [responseObject[@"success"] boolValue];
            if (isSuccess) {
                if (resultBlock) {
                    resultBlock(responseObject,nil);
                }
            } else {
                NSInteger errorCode = [responseObject[@"code"] integerValue];
                NSString *errorMessage = responseObject[@"errorMsg"];
                if (errorCode == TOKEN_EXPIRES_ERROR_CODE) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)kTokenExpiresNotification object:self userInfo:nil];
                    return;
                }
                NSError *error = [NSError errorWithDomain:kTyreErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
                if (resultBlock) {
                    resultBlock(nil,error);
                }
            }
        }
    }];
    [dataTask resume];
    return dataTask;
}



#pragma mark - Public

- (NSURLSessionDataTask *)getPath:(NSString *)path params:(NSDictionary *)params resultBlock:(ResultBlock)resultBlock
{
    return [self dataTaskWithHTTPMethod:@"GET" URLString:path parameters:params resultBlock:resultBlock];
}

- (NSURLSessionDataTask *)postPath:(NSString *)path params:(NSDictionary *)params resultBlock:(ResultBlock)resultBlock
{
    return [self dataTaskWithHTTPMethod:@"POST" URLString:path parameters:params resultBlock:resultBlock];
}

- (NSURLSessionDataTask *)putPath:(NSString *)path params:(NSDictionary *)params resultBlock:(ResultBlock)resultBlock
{
    return [self dataTaskWithHTTPMethod:@"PUT" URLString:path parameters:params resultBlock:resultBlock];
}

- (NSURLSessionDataTask *)deletePath:(NSString *)path params:(NSDictionary *)params resultBlock:(ResultBlock)resultBlock
{
    return [self dataTaskWithHTTPMethod:@"DELETE" URLString:path parameters:params resultBlock:resultBlock];
}

- (RACSignal *)dataTaskWithHTTPMethod:(NSString *)method path:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass
{
    return [[[self rac_requestPath:path parameters:[self getFinialParameters:params] method:method] reduceEach:^id(NSHTTPURLResponse *response, id responseObject){
        NSLog(@"%@",responseObject);
        return [self parsedResponseOfClass:resultClass fromJSON:responseObject];
    }]concat];
}

- (RACSignal *)getWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass
{
    return [self dataTaskWithHTTPMethod:@"GET" path:path params:params resultClass:resultClass];
}
- (RACSignal *)postWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass
{
    NSLog(@"%@",params);
    return [self dataTaskWithHTTPMethod:@"POST" path:path params:params resultClass:resultClass];
}
- (RACSignal *)putWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass
{
    return [self dataTaskWithHTTPMethod:@"PUT" path:path params:params resultClass:resultClass];
}
- (RACSignal *)deleteWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass
{
    return [self dataTaskWithHTTPMethod:@"DELETE" path:path params:params resultClass:resultClass];
}

#pragma mark - private
+ (NSError *)parsingErrorWithFailureReason:(NSString *)localizedFailureReason
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Could not parse the service response.", @"");
    
    if (localizedFailureReason != nil) {
        userInfo[NSLocalizedDescriptionKey] = localizedFailureReason;
    }
    
    return [NSError errorWithDomain:YXParserErrorDomain code:YXParserErrorJSONParsingFailed userInfo:userInfo];
}
- (RACSignal *)parsedResponseOfClass:(Class)resultClass fromJSON:(id)responseObject
{
    //    NSParameterAssert(resultClass == nil || [resultClass isSubclassOfClass:JSONModel.class]);
    
    return [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
        void (^parseJSONDictionary)(NSDictionary *) = ^(NSDictionary *JSONDictionary) {
            if (resultClass == nil) {
                BOOL isSuccess = [responseObject[@"success"] boolValue];
                [subscriber sendNext:@(isSuccess)];
                return;
            }

            if ([responseObject[kSuccessKey] boolValue] == NO) {
                NSInteger errorCode = [responseObject[kCodeKey] integerValue];
                NSString *errorMessage = responseObject[kMessageKey];
                NSError *error = [NSError errorWithDomain:kTyreErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey : errorMessage}];

                
                [subscriber sendError:error];
                if (errorCode == kLoginErrorCode) {
                    [[NSNotificationCenter defaultCenter]postNotificationName:@"kNotificationLoginOut" object:nil];
                }
                return;
            }

            NSError *error = nil;
            JSONModel *parsedObject = [[resultClass alloc]initWithDictionary:responseObject error:&error];
            if (parsedObject == nil) {
                // Don't treat "no class found" errors as real parsing failures.
                // In theory, this makes parsing code forward-compatible with
                // API additions.
                [subscriber sendError:error];
                return;
            }
            
            NSAssert([parsedObject isKindOfClass:JSONModel.class], @"Parsed model object is not an JSONModel: %@", parsedObject);
            
            [subscriber sendNext:parsedObject];
        };
        
        if ([responseObject isKindOfClass:NSDictionary.class]) {
            parseJSONDictionary(responseObject);
            [subscriber sendCompleted];
        }
        else if (responseObject != nil) {
            NSString *failureReason = [NSString stringWithFormat:NSLocalizedString(@"Response wasn't an array or dictionary (%@): %@", @""), [responseObject class], responseObject];
            [subscriber sendError:[[self class]parsingErrorWithFailureReason:failureReason]];
            
        }
        else if (responseObject == nil) {
            [subscriber sendNext:responseObject];
            [subscriber sendCompleted];
        }
        
        return nil;
    }];
}


@end

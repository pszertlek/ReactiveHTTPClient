//
//  HttpClient.h
//  Motormaster
//
//  Created by Coco on 10/26/15.
//  Copyright (c) 2015 Hangzhou Xuanchao Technology Co. Ltd. All rights reserved.
//

#import <AFHTTPSessionManager.h>
#import "AFHTTPSessionManager+RACSupport.h"

typedef NS_ENUM(NSInteger,TSEnviormentType) {
    TSEnviormentTypeDevelop = 0,
    TSEnviormentTypeTest,
    TSEnviormentTypeStable,
    TSEnviormentTypeProduction,
    TSEnviormentTypeCustom,
};

@class RACSignal;
extern NSString * const kTokenExpiresNotification;
extern NSInteger TOKEN_EXPIRES_ERROR_CODE;

typedef void (^ResultBlock)(id responseObject, NSError *error);

@interface HttpClient : AFHTTPSessionManager

@property (nonatomic ,strong) NSString *sessionId;

+ (instancetype)sharedClient;


- (NSURLSessionDataTask *)getPath:(NSString *)path
                           params:(NSDictionary *)params
                      resultBlock:(ResultBlock)resultBlock;

- (NSURLSessionDataTask *)postPath:(NSString *)path
                            params:(NSDictionary *)params
                       resultBlock:(ResultBlock)resultBlock;

- (NSURLSessionDataTask *)putPath:(NSString *)path
                           params:(NSDictionary *)params
                      resultBlock:(ResultBlock)resultBlock;
- (NSURLSessionDataTask *)deletePath:(NSString *)path
                              params:(NSDictionary *)params
                         resultBlock:(ResultBlock)resultBlock;
- (NSDictionary *)getFinialParameters:(NSDictionary *)params;

- (RACSignal *)dataTaskWithHTTPMethod:(NSString *)method path:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass;
- (RACSignal *)getWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass;
- (RACSignal *)postWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass;
- (RACSignal *)putWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass;
- (RACSignal *)deleteWithPath:(NSString *)path params:(NSDictionary *)params resultClass:(Class)resultClass;
@end

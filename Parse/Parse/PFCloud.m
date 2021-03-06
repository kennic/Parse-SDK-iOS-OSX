/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFCloud.h"

#import "BFTask+Private.h"
#import "PFCloudCodeController.h"
#import "PFCommandResult.h"
#import "PFCoreManager.h"
#import "PFUserPrivate.h"
#import "Parse_Private.h"

@implementation PFCloud

///--------------------------------------
#pragma mark - Public
///--------------------------------------

+ (BFTask *)callFunctionInBackground:(NSString *)functionName withParameters:(NSDictionary *)parameters {
    return [self callFunctionInBackground:functionName withParameters:parameters cachePolicy:kPFCachePolicyNetworkOnly maxCacheAge:60];
}

+ (BFTask *)callFunctionInBackground:(NSString *)functionName
                      withParameters:(NSDictionary *)parameters
                         cachePolicy:(PFCachePolicy)cachePolicy
                         maxCacheAge:(NSTimeInterval)maxCacheAge {
    return [[PFUser _getCurrentUserSessionTokenAsync] continueWithBlock:^id(BFTask *task) {
        NSString *sessionToken = task.result;
        PFCloudCodeController *controller = [Parse _currentManager].coreManager.cloudCodeController;
        return [controller callCloudCodeFunctionAsync:functionName
                                       withParameters:parameters
                                          cachePolicy:cachePolicy
                                          maxCacheAge:maxCacheAge
                                         sessionToken:sessionToken];
    }];
}

+ (void)callFunctionInBackground:(NSString *)function
                  withParameters:(NSDictionary *)parameters
                     cachePolicy:(PFCachePolicy)cachePolicy
                     maxCacheAge:(NSTimeInterval)maxCacheAge
                           block:(PFIdResultBlock)block {
    if (cachePolicy == kPFCachePolicyCacheThenNetwork) {
        [[self callFunctionInBackground:function withParameters:parameters cachePolicy:kPFCachePolicyCacheOnly maxCacheAge:maxCacheAge] thenCallBackOnMainThreadAsync:^(id result, NSError *error) {
            if (error == NULL) {
                if ([NSThread currentThread].isMainThread) {
                    block(result, error);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        block(result, error);
                    });
                }
            }
            
            [[self callFunctionInBackground:function withParameters:parameters cachePolicy:kPFCachePolicyNetworkOnly maxCacheAge:maxCacheAge] thenCallBackOnMainThreadAsync:block];
        }];
    }
    else {
        [[self callFunctionInBackground:function withParameters:parameters cachePolicy:cachePolicy maxCacheAge:maxCacheAge] thenCallBackOnMainThreadAsync:block];
    }
}

@end

///--------------------------------------
#pragma mark - Synchronous
///--------------------------------------

@implementation PFCloud (Synchronous)

+ (id)callFunction:(NSString *)function withParameters:(NSDictionary *)parameters {
    return [self callFunction:function withParameters:parameters error:nil];
}

+ (id)callFunction:(NSString *)function withParameters:(NSDictionary *)parameters error:(NSError **)error {
    return [[self callFunctionInBackground:function withParameters:parameters] waitForResult:error];
}

@end

///--------------------------------------
#pragma mark - Deprecated
///--------------------------------------

@implementation PFCloud (Deprecated)

+ (void)callFunctionInBackground:(NSString *)function
                  withParameters:(nullable NSDictionary *)parameters
                          target:(nullable id)target
                        selector:(nullable SEL)selector {
    [self callFunctionInBackground:function withParameters:parameters cachePolicy:kPFCachePolicyNetworkOnly maxCacheAge:60 block:^(id results, NSError *error) {
        [PFInternalUtils safePerformSelector:selector withTarget:target object:results object:error];
    }];
}

@end

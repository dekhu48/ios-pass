// AUTOGENERATED FILE - DO NOT MODIFY!
// This file generated by Djinni from open_pgp.djinni

#import <Foundation/Foundation.h>
@class PMNIOrganization;


@interface PMNIOrganization : NSObject

- (nonnull NSArray<NSString *> *)getValues;

- (nonnull NSString *)getValue;

+ (nullable PMNIOrganization *)createInstance:(nonnull NSString *)type
                                        value:(nonnull NSString *)value;

@end

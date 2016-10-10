//
//  protobuf2dict.h
//  protobuf2dict
//
//  Created by Glider on 2016/10/9.
//  Copyright © 2016年 Glider. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GLDProtobufHelper : NSObject
- (NSDictionary*)readMessageFromData:(NSData *)data
                           protoFile:(NSString*)protofile
                         messageName:(NSString*)msgName;

- (NSData *)generateMessageFromProtoFile:(NSString *)protofile
                             messageName:(NSString*)msgName
                                  params:(NSDictionary*)param;
@end

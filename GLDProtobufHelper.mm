//
//  protobuf2dict.m
//  protobuf2dict
//
//  Created by Glider on 2016/10/9.
//  Copyright © 2016年 Glider. All rights reserved.
//

#import "GLDProtobufHelper.h"

#include <iostream>
#include <sstream>
#include <google/protobuf/descriptor.h>
#include <google/protobuf/descriptor.pb.h>
#include <google/protobuf/dynamic_message.h>
#include <google/protobuf/compiler/importer.h>
#include <google/protobuf/io/coded_stream.h>

using namespace std;
using namespace google::protobuf;
using namespace google::protobuf::compiler;


@implementation GLDProtobufHelper
- (NSDictionary*)readMessageFromData:(NSData *)data
                           protoFile:(NSString*)protofile
                         messageName:(NSString*)msgName
{
    DiskSourceTree sourceTree;
    NSString *dir = [protofile stringByDeletingLastPathComponent];
    sourceTree.MapPath("", dir.UTF8String);
    
    Importer importer(&sourceTree, NULL);
    importer.Import(protofile.lastPathComponent.UTF8String);
    
    const Descriptor *descriptor = importer.pool()->FindMessageTypeByName(msgName.UTF8String);
    if (descriptor == NULL) {
        return NULL;
    }
    google::protobuf::DynamicMessageFactory factory;
    const google::protobuf::Message *message = factory.GetPrototype(descriptor);
    google::protobuf::Message *msg = message->New();
    
    std::string str((char *)data.bytes, data.length);
    std::istringstream stream(str);
    if (msg->ParseFromIstream(&stream) == false) {
        NSLog(@"Parse from data failed! [%@,%@]", protofile, msgName);
        return nil;
    }
    return [self parseProtoMessage:msg];
bail:
    return nil;
}

- (id)parseProtoMessage:(const google::protobuf::Message *)message
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    const google::protobuf::Descriptor *descriptor = message->GetDescriptor();
    const google::protobuf::Reflection *reflection = message->GetReflection();
    
    for (int i=0; i<descriptor->field_count(); i++) {
        const google::protobuf::FieldDescriptor *field = descriptor->field(i);
        NSString *key = [NSString stringWithUTF8String:field->name().c_str()];
        
        id value = [self getValueFromField:field
                                   message:*message
                                reflection:reflection];
        if (value == nil) {
            NSLog(@"Retrive field '%@' value failed!", key);
            goto bail;
        }
        
        dict[key] = value;
    }
    return dict;
bail:
    return nil;
}

- (id)getValueFromField:(const google::protobuf::FieldDescriptor *)field
                message:(const google::protobuf::Message &)message
             reflection:(const google::protobuf::Reflection *)reflection
{
    if (field->is_repeated()) {
        NSMutableArray  *array = [NSMutableArray array];
        
#define CHECK_REPEATED_NUMBER_TYPE(type)\
google::protobuf::RepeatedField<type> r = reflection->GetRepeatedField<type>(message, field);\
for (int i=0; i<r.size(); i++) {\
type element = r.Get(i);\
[array addObject:@(element)];\
}
        
        switch (field->cpp_type()) {
            case google::protobuf::FieldDescriptor::CPPTYPE_BOOL:
            {
                CHECK_REPEATED_NUMBER_TYPE(bool);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_FLOAT:
            {
                CHECK_REPEATED_NUMBER_TYPE(float);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_DOUBLE:
            {
                CHECK_REPEATED_NUMBER_TYPE(double);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_INT32:
            {
                CHECK_REPEATED_NUMBER_TYPE(int32_t);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT32:
            {
                CHECK_REPEATED_NUMBER_TYPE(uint32_t);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_INT64:
            {
                CHECK_REPEATED_NUMBER_TYPE(int64_t);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT64:
            {
                CHECK_REPEATED_NUMBER_TYPE(uint64_t);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_STRING:
            {
                for (int i=0; i<reflection->FieldSize(message, field); i++) {
                    std::string s = reflection->GetRepeatedString(message, field, i);
                    NSString *str = [NSString stringWithUTF8String:s.c_str()];
                    if (str == nil) {
                        return nil;
                    }
                    [array addObject:str];
                }
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_ENUM:
            {
                for (int i=0; i<reflection->FieldSize(message, field); i++) {
                    const google::protobuf::EnumValueDescriptor *e = reflection->GetRepeatedEnum(message, field, i);
                    NSString *str = [NSString stringWithUTF8String:e->name().c_str()];
                    if (str == nil) {
                        return nil;
                    }
                    [array addObject:str];
                }
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE:
            {
                for (int i=0; i<reflection->FieldSize(message, field); i++) {
                    const google::protobuf::Message &m = reflection->GetRepeatedMessage(message, field, i);
                    id val = [self parseProtoMessage:&m];
                    if (val == nil) {
                        return nil;
                    }
                    [array addObject:val];
                }
                break;
            }
            default:
                break;
        }
#undef CHECK_REPEATED_NUMBER_TYPE
        return array;
    }
    else {
        
#define CHECK_NUMBER_TYPE(type, cpptype) \
    type v = reflection->Get##cpptype(message, field);\
    return @(v);\

#define CHECK_STRING_TYPE\
    string v = reflection->GetString(message, field);\
    NSString *str = [NSString stringWithUTF8String:v.c_str()];\
    return str;\

        switch (field->cpp_type()) {
            case google::protobuf::FieldDescriptor::CPPTYPE_BOOL:
            {
                CHECK_NUMBER_TYPE(BOOL, Bool);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_FLOAT:
            {
                CHECK_NUMBER_TYPE(float, Float);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_DOUBLE:
            {
                CHECK_NUMBER_TYPE(double, Double);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_INT32:
            {
                CHECK_NUMBER_TYPE(int32_t, Int32);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT32:
            {
                CHECK_NUMBER_TYPE(uint32_t, UInt32);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_INT64:
            {
                CHECK_NUMBER_TYPE(int64_t, Int64);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_UINT64:
            {
                CHECK_NUMBER_TYPE(uint64_t, UInt64);
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_STRING:
            {
                CHECK_STRING_TYPE;
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_ENUM:
            {
                const google::protobuf::EnumValueDescriptor *e = reflection->GetEnum(message, field);
                NSString *str = [NSString stringWithUTF8String:e->name().c_str()];
                return str;
                break;
            }
            case google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE:
            {
                const google::protobuf::Message &m = reflection->GetMessage(message, field);
                return [self parseProtoMessage:&m];
                break;
            }
            default:
                break;
        }
#undef CHECK_NUMBER_TYPE
#undef CHECK_STRING_TYPE
    }
    return nil;
}

#pragma mark - Protobuf Generate Functions
- (NSData *)generateMessageFromProtoFile:(NSString *)protofile
                             messageName:(NSString*)msgName
                                  params:(NSDictionary*)param
{
    DiskSourceTree sourceTree;
    NSString *dir = [protofile stringByDeletingLastPathComponent];
    sourceTree.MapPath("", dir.UTF8String);
    
    Importer importer(&sourceTree, NULL);
    importer.Import(protofile.lastPathComponent.UTF8String);
    
    const Descriptor *descriptor = importer.pool()->FindMessageTypeByName(msgName.UTF8String);
    if (descriptor == NULL) {
        return NULL;
    }
    
    google::protobuf::DynamicMessageFactory factory;
    const google::protobuf::Message *message = factory.GetPrototype(descriptor);
    google::protobuf::Message *msg = message->New();
    const google::protobuf::Reflection *reflection = msg->GetReflection();
    
    if (![self processMessageDescriptor:descriptor
                                message:msg
                             reflection:reflection
                                 params:param]) {
        delete msg;
        return nil;
    }
    
    std::string output;
    msg->SerializeToString(&output);
    NSData *data = [NSData dataWithBytes:output.c_str() length:output.size()];
    
    delete msg;
    return data;
}

- (BOOL)processMessageDescriptor:(const google::protobuf::Descriptor*)descriptor
                         message:(google::protobuf::Message*)msg
                      reflection:(const google::protobuf::Reflection*)reflection
                          params:(NSDictionary *)param

{
    for (NSString *key in param) {
        const google::protobuf::FieldDescriptor *field = NULL;
        field = descriptor->FindFieldByName(key.UTF8String);
        if (field == NULL) {
            goto bail;
        }
        
        id value = param[key];
        if (field->is_repeated()) {
            if (![value isKindOfClass:[NSArray class]]) {
                goto bail;
            }
            
            NSArray *val = (NSArray *)value;
            for (int i=0; i<[val count]; i++) {
                if (![self setValue:val[i]
                                 to:field
                            message:msg
                         reflection:reflection]) {
                    goto bail;
                }
            }
        }
        else {
            if (![self setValue:value
                             to:field
                        message:msg
                     reflection:reflection]) {
                goto bail;
            }
        }
    }
    return YES;
bail:
    return NO;
}

- (BOOL)setValue:(id)value
              to:(const google::protobuf::FieldDescriptor*)field
         message:(google::protobuf::Message*)msg
      reflection:(const google::protobuf::Reflection*)reflection
{
#define CHECK_FIELD_TYPE(val, cls) \
if (![value isKindOfClass:[cls class]])\
return NO;\
cls *n = (cls*)val
    
    switch (field->cpp_type()) {
        case google::protobuf::FieldDescriptor::CPPTYPE_INT32:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddInt32(msg, field, (int32_t)n.integerValue);
            else
                reflection->SetInt32(msg, field, (int32_t)n.integerValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_UINT32:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddUInt32(msg, field, (uint32_t)n.unsignedIntValue);
            else
                reflection->SetUInt32(msg, field, (uint32_t)n.unsignedIntValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_INT64:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddInt64(msg, field, (int64_t)n.longLongValue);
            else
                reflection->SetInt64(msg, field, (int64_t)n.longLongValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_UINT64:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddUInt64(msg, field, (uint64_t)n.unsignedLongLongValue);
            else
                reflection->SetUInt64(msg, field, (uint64_t)n.unsignedLongLongValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_FLOAT:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddFloat(msg, field, (float)n.floatValue);
            else
                reflection->SetFloat(msg, field, (float)n.floatValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_DOUBLE:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddDouble(msg, field, (float)n.doubleValue);
            else
                reflection->SetDouble(msg, field, (float)n.doubleValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_BOOL:
        {
            CHECK_FIELD_TYPE(value, NSNumber);
            if (field->is_repeated())
                reflection->AddBool(msg, field, (bool)n.boolValue);
            else
                reflection->SetBool(msg, field, (bool)n.boolValue);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_STRING:
        {
            CHECK_FIELD_TYPE(value, NSString);
            if (field->is_repeated())
                reflection->AddString(msg, field, n.UTF8String);
            else
                reflection->SetString(msg, field, n.UTF8String);
            break;
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_ENUM:
        {
            CHECK_FIELD_TYPE(value, NSString);
            const google::protobuf::EnumDescriptor *enumDescriptor = field->enum_type();
            for (int i=0; i<enumDescriptor->value_count(); i++) {
                const google::protobuf::EnumValueDescriptor *valueDescriptor = enumDescriptor->value(i);
                if ([n isEqualToString:[NSString stringWithUTF8String:valueDescriptor->name().c_str()]]) {
                    if (field->is_repeated())
                        reflection->AddEnum(msg, field, valueDescriptor);
                    else
                        reflection->SetEnum(msg, field, valueDescriptor);
                    break;
                }
            }
            break;
            
        }
        case google::protobuf::FieldDescriptor::CPPTYPE_MESSAGE:
        {
            CHECK_FIELD_TYPE(value, NSDictionary);
            const google::protobuf::Descriptor *subDescriptor = field->message_type();
            google::protobuf::Message *subMsg = NULL;
            if (field->is_repeated()) {
                subMsg = reflection->AddMessage(msg, field);
            }
            else {
                subMsg = reflection->MutableMessage(msg, field);
            }
            
            const google::protobuf::Reflection *subReflection = subMsg->GetReflection();
            if (![self processMessageDescriptor:subDescriptor
                                        message:subMsg
                                     reflection:(const Reflection*)subReflection
                                         params:n]) {
                return NO;
            }
            break;
        }
        default:
            return NO;
    }
#undef CHECK_FIELD_TYPE
    return YES;
}

@end

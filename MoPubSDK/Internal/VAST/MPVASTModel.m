//
//  MPVASTModel.m
//  MoPub
//
//  Copyright (c) 2015 MoPub. All rights reserved.
//

#import "MPVASTModel.h"
#import "MPVASTStringUtilities.h"
#import "MPLogging.h"
#import <objc/runtime.h>

id<MPObjectMapper> MPParseArrayOf(id<MPObjectMapper> internalMapper)
{
    return [[MPNSArrayMapper alloc] initWithInternalMapper:internalMapper];
}

id<MPObjectMapper> MPParseURLFromString()
{
    return [[MPNSStringToNSURLMapper alloc] init];
}

id<MPObjectMapper> MPParseNumberFromString(NSNumberFormatterStyle numberStyle)
{
    return [[MPStringToNumberMapper alloc] initWithNumberStyle:numberStyle];
}

id<MPObjectMapper> MPParseTimeIntervalFromDurationString()
{
    return [[MPDurationStringToTimeIntervalMapper alloc] init];
}

id<MPObjectMapper> MPParseClass(Class destinationClass)
{
    return [[MPClassMapper alloc] initWithDestinationClass:destinationClass];
}

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MPNSStringToNSURLMapper

- (id)mappedObjectFromSourceObject:(id)object
{
    NSString *URLString = [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [NSURL URLWithString:URLString];
}

- (Class)requiredSourceObjectClass
{
    return [NSString class];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MPDurationStringToTimeIntervalMapper

- (id)mappedObjectFromSourceObject:(id)object
{
    return @([MPVASTStringUtilities timeIntervalFromString:object]);
}

- (Class)requiredSourceObjectClass
{
    return [NSString class];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MPStringToNumberMapper ()

@property (nonatomic) NSNumberFormatter *numberFormatter;

@end

@implementation MPStringToNumberMapper

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithNumberStyle:(NSNumberFormatterStyle)numberStyle
{
    self = [super init];
    if (self) {
        _numberFormatter = [[NSNumberFormatter alloc] init];
        _numberFormatter.numberStyle = numberStyle;
    }
    return self;
}

- (id)mappedObjectFromSourceObject:(id)object
{
    return [self.numberFormatter numberFromString:object];
}

- (Class)requiredSourceObjectClass
{
    return [NSString class];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MPClassMapper ()

@property (nonatomic) Class destinationClass;

@end

@implementation MPClassMapper

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithDestinationClass:(Class)destinationClass
{
    self = [super init];
    if (self) {
        _destinationClass = destinationClass;
    }
    return self;
}

- (id)mappedObjectFromSourceObject:(id)object
{
    if (![self.destinationClass isSubclassOfClass:[MPVASTModel class]] ||
        ![self.destinationClass instancesRespondToSelector:@selector(initWithDictionary:)]) {
        return nil;
    }

    return [[self.destinationClass alloc] initWithDictionary:object];
}

- (Class)requiredSourceObjectClass
{
    return [NSDictionary class];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MPNSArrayMapper ()

@property (nonatomic) id<MPObjectMapper> mapper;

@end

@implementation MPNSArrayMapper

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithInternalMapper:(id<MPObjectMapper>)mapper
{
    self = [super init];
    if (self) {
        _mapper = mapper;
    }
    return self;
}

- (id)mappedObjectFromSourceObject:(id)object
{
    NSMutableArray *result = [NSMutableArray array];

    if ([object isKindOfClass:[NSArray class]]) {
        for (id obj in object) {
            if ([obj isKindOfClass:[self.mapper requiredSourceObjectClass]]) {
                id model = [self.mapper mappedObjectFromSourceObject:obj];
                if (model) {
                    [result addObject:model];
                }
            }
        }
    } else if ([object isKindOfClass:[self.mapper requiredSourceObjectClass]]) {
        id model = [self.mapper mappedObjectFromSourceObject:object];
        if (model) {
            [result addObject:model];
        }
    }

    return result;
}

- (Class)requiredSourceObjectClass
{
    return [NSArray class];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MPVASTModel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        if (!dictionary) {
            return nil;
        }

        NSDictionary *modelMap = [[self class] modelMap];
        for (NSString *key in modelMap) {
            if ([self hasPropertyNamed:key]) {
                id modelMapValue = modelMap[key];

                if ([modelMapValue isKindOfClass:[NSString class]]) {
                    // The simple case: grab the value corresponding to the given key path and
                    // assign it to the property.
                    id value = [dictionary valueForKeyPath:modelMapValue];
                    if (value) {
                        [self setValue:value forKey:key];
                    }
                } else if ([modelMapValue isKindOfClass:[NSArray class]] && [modelMapValue count] == 2) {
                    NSString *dictionaryKeyPath = modelMapValue[0];
                    id<MPObjectMapper> mapper = modelMapValue[1];

                    if ([mapper conformsToProtocol:@protocol(MPObjectMapper)]) {
                        id sourceObject = [dictionary valueForKeyPath:dictionaryKeyPath];
                        if (sourceObject) {
                            if ([sourceObject isKindOfClass:[mapper requiredSourceObjectClass]]) {
                                id model = [mapper mappedObjectFromSourceObject:sourceObject];
                                if (model) {
                                    [self setValue:model forKey:key];
                                }
                            }
                        }
                    }
                } else {
                    MPLogError(@"Could not populate %@ of class %@ because its mapper is invalid.",
                              key, NSStringFromClass([self class]));
                }
            }
        }
    }
    return self;
}

+ (NSDictionary *)modelMap
{
    // Implemented by subclasses.
    return nil;
}

- (id)generateModelFromDictionaryValue:(id)value modelProvider:(id(^)(id))provider {
    if (value && [value isKindOfClass:[NSArray class]] && [value count] > 0) {
        return provider(value[0]);
    } else if (value && [value isKindOfClass:[NSDictionary class]]) {
        return provider(value);
    } else {
        return nil;
    }
}

- (NSArray *)generateModelsFromDictionaryValue:(id)value modelProvider:(id(^)(id))provider {
    NSMutableArray *models = [NSMutableArray array];

    if (value && [value isKindOfClass:[NSArray class]]) {
        for (NSDictionary *dictionary in value) {
            id model = provider(dictionary);
            if (model) {
                [models addObject:model];
            }
        }
    } else if (value && [value isKindOfClass:[NSDictionary class]]) {
        id model = provider(value);
        if (model) {
            [models addObject:model];
        }
    }

    return [models copy];
}

#pragma mark - Internal

- (BOOL)hasPropertyNamed:(NSString *)name
{
    // This method uses the objc runtime API to check whether the current model class has a given
    // property. After we grab the set of properties for a given class, we cache it for efficiency.

    static NSMutableDictionary *propertyNamesForClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        propertyNamesForClass = [NSMutableDictionary dictionary];
    });

    NSString *className = NSStringFromClass([self class]);
    NSMutableSet *propertyNames = propertyNamesForClass[className];

    if (!propertyNames) {
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);
        propertyNames = [NSMutableSet setWithCapacity:propertyCount];
        for (unsigned int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            [propertyNames addObject:[NSString stringWithUTF8String:property_getName(property)]];
        }
        propertyNamesForClass[className] = propertyNames;
        free(properties);
    }

    return [propertyNames containsObject:name];
}

- (NSString *)description
{
    NSMutableString *descriptionString = [NSMutableString stringWithFormat:@"%@:", NSStringFromClass([self class])];

    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList([self class], &propertyCount);

    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [[NSString alloc] initWithUTF8String:property_getName(property)];
        [descriptionString appendFormat:@"\n\t%s = %s", propertyName.UTF8String, [[self valueForKey:propertyName] description].UTF8String];
    }

    free(properties);
    return descriptionString;
}

@end

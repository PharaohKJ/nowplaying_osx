//
//  NSAppleScript+Utils.m
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NSAppleScript+Utils.h"


@implementation NSAppleScript (Utils)

+ (NSAppleScript *)scriptWithCompilingForSourceFileNamed:(NSString *)scriptName
{
    return [self scriptWithCompilingForSourceFileNamed:scriptName replaceDict:nil];
}

+ (NSAppleScript *)scriptWithCompilingForSourceFileNamed:(NSString *)scriptName replaceDict:(NSDictionary *)replaceDict
{
    NSError *error = nil;
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:scriptName.stringByDeletingPathExtension
                                             withExtension:scriptName.pathExtension];
    if (!fileURL) {
        NSLog(@"File not found for AppleScript: %@", scriptName);
        return nil;
    }
    
    NSString *source = [NSString stringWithContentsOfURL:fileURL
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    if (!source) {
        NSLog(@"Failed to load AppleScript source as UTF-8: %@", scriptName);
        return nil;
    }
    
    if (replaceDict) {
        for (NSString *replaceKey in replaceDict) {
            NSString *replaceString = replaceDict[replaceKey];
            source = [source stringByReplacingOccurrencesOfString:replaceKey withString:replaceString];
        }
    }
    
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    NSDictionary *errorDict = nil;
    if (![script compileAndReturnError:&errorDict]) {
        NSLog(@"Failed to compile AppleScript: %@ (%@)", scriptName, errorDict);
        return nil;
    }
    return script;
}

- (void)execute
{
    NSDictionary *errorInfo = nil;
    [self executeAndReturnError:&errorInfo];
}

- (NSData *)executeAndReturnData
{
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [self executeAndReturnError:&errorInfo];
    return desc.data;
}

- (double)executeAndReturnDoubleValue
{
    return [self executeAndReturnStringValue].doubleValue;
}

- (int)executeAndReturnIntValue
{
    return [self executeAndReturnStringValue].intValue;
}

- (NSString *)executeAndReturnStringValue
{
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [self executeAndReturnError:&errorInfo];
    return desc.stringValue;
}

@end


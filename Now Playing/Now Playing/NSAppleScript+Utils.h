//
//  NSAppleScript+Utils.h
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSAppleScript (Utils)

+ (NSAppleScript *)scriptWithCompilingForSourceFileNamed:(NSString *)scriptName;
+ (NSAppleScript *)scriptWithCompilingForSourceFileNamed:(NSString *)scriptName replaceDict:(NSDictionary *)replaceDict;

- (void)execute;

- (NSData *)executeAndReturnData;
- (double)executeAndReturnDoubleValue;
- (int)executeAndReturnIntValue;
- (NSString *)executeAndReturnStringValue;

@end


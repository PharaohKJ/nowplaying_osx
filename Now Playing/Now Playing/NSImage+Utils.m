//
//  NSImage+Utils.m
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NSImage+Utils.h"


@implementation NSImage (Utils)

- (NSImage *)resizedImageForSize:(NSSize)size
{
    NSImage *newImage = [[NSImage alloc] initWithSize:size];
    [newImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [self drawInRect:NSMakeRect(0, 0, size.width, size.height)
            fromRect:NSZeroRect
           operation:NSCompositeSourceOver
            fraction:1.0f];
    [newImage unlockFocus];
    return newImage;
}

@end

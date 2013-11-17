//
//  NSWindow+AccessoryView.m
//  Now Playing
//
//  Created by numata on 2013/11/17.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NSWindow+AccessoryView.h"


@implementation NSWindow (AccessoryView)

-(void)addViewToTitleBar:(NSView *)viewToAdd atXPosition:(CGFloat)x
{
    viewToAdd.frame = NSMakeRect(x, [[self contentView] frame].size.height,
                                 viewToAdd.frame.size.width, [self heightOfTitleBar]);
    
    NSUInteger mask = 0;
    if (x > self.frame.size.width / 2.0) {
        mask |= NSViewMinXMargin;
    } else {
        mask |= NSViewMaxXMargin;
    }
    [viewToAdd setAutoresizingMask:(mask | NSViewMinYMargin)];
    [[[self contentView] superview] addSubview:viewToAdd];
}

-(CGFloat)heightOfTitleBar
{
    NSRect outerFrame = [[[self contentView] superview] frame];
    NSRect innerFrame = [[self contentView] frame];
    return outerFrame.size.height - innerFrame.size.height;
}

@end


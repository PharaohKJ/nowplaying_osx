//
//  NPPlayPositionView.m
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPPlayPositionView.h"
#import "NPAppDelegate.h"


@implementation NPPlayPositionView {
    NSColor *bgColor;
    NSColor *bgColor2;
    NSColor *barColor;
    
    NSTimeInterval tempTime;
    BOOL isDragging;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        bgColor = [NSColor colorWithCalibratedWhite:0.96 alpha:1.0];
        bgColor2 = [NSColor colorWithCalibratedWhite:0.88 alpha:1.0];
        barColor = [NSColor colorWithCalibratedRed:1.0 green:0.176 blue:0.333 alpha:1.0];
        
        self.currentTime = 0.1;
        self.trackTime = 5.0;
        
        isDragging = NO;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect frame = self.frame;
    frame.origin = NSZeroPoint;
    
    [bgColor set];
    NSRectFill(frame);
    
    [bgColor2 set];
    NSRectFill(NSMakeRect(0, 8, frame.size.width, 7));
    
    NSTimeInterval theTime = (isDragging? tempTime: self.currentTime);
    
    CGFloat barPos = (theTime / self.trackTime) * (frame.size.width - 2);
    [barColor set];
    NSRectFill(NSMakeRect(barPos, 4, 2, 15));
}

- (void)mouseDown:(NSEvent *)theEvent
{
    isDragging = YES;
    
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    CGFloat thePos = (pos.x - 1) / self.frame.size.width;
    tempTime = thePos * self.trackTime;

    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSRect bounds = self.bounds;
    bounds.origin.x -= 100;
    bounds.size.width += 200;
    if (NSPointInRect(pos, bounds)) {
        CGFloat thePos = (pos.x - 1) / self.frame.size.width;
        if (thePos < 0.0) {
            thePos = 0.0;
        } else if (thePos > 1.0) {
            thePos = 1.0;
        }
        tempTime = thePos * self.trackTime;
    } else {
        tempTime = self.currentTime;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    isDragging = NO;
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSRect bounds = self.bounds;
    bounds.origin.x -= 100;
    bounds.size.width += 200;
    if (NSPointInRect(pos, bounds)) {
        CGFloat thePos = (pos.x - 1) / self.frame.size.width;
        if (thePos < 0.0) {
            thePos = 0.0;
        } else if (thePos > 1.0) {
            thePos = 1.0;
        }
        tempTime = thePos * self.trackTime;
        [[NPAppDelegate sharedInstance] setPlayerPosition:tempTime];
        self.currentTime = tempTime;
    }
    [self setNeedsDisplay:YES];
}

@end


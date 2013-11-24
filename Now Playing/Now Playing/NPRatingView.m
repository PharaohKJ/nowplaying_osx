//
//  NPRatingView.m
//  Now Playing
//
//  Created by numata on 2013/11/24.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPRatingView.h"
#import "NPAppDelegate.h"


static const float NPRatingFontSize = 16.0f;
static const float NPRatingPaddingSize = 3.0f;
static const float NPRatingStartX = 28.0f;
static const float NPRatingStartY = 4.0f;


@implementation NPRatingView {
    NSFont *font;
    BOOL isDragging;
    int oldRating;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
    return YES;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.rating = 0;
        isDragging = NO;
        font = [NSFont fontWithName:@"Helvetica" size:NPRatingFontSize];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    NSRect frame = self.frame;
    frame.origin = NSZeroPoint;

    [[NSColor whiteColor] set];
    NSRectFill(frame);

    NSString *starStr = @"★";
    NSString *dotStr = @"・";

    NSDictionary *drawAttr = @{ NSFontAttributeName:font,
                                NSForegroundColorAttributeName:[NSColor blackColor] };
    
    NSPoint drawPos = NSMakePoint(NPRatingStartX, NPRatingStartY);
    int i = 0;
    for (; i < self.rating; i++) {
        [starStr drawAtPoint:drawPos
              withAttributes:drawAttr];
        drawPos.x += NPRatingFontSize + NPRatingPaddingSize;
    }
    
    drawAttr = @{ NSFontAttributeName:font,
                  NSForegroundColorAttributeName:[NSColor lightGrayColor] };

    for (; i < 5; i++) {
        [dotStr drawAtPoint:drawPos
              withAttributes:drawAttr];
        drawPos.x += NPRatingFontSize + NPRatingPaddingSize;
    }
}

- (int)mousePosXToRating:(float)mouseX
{
    int ret;
    if (mouseX < NPRatingStartX) {
        ret = 0;
    } else {
        ret = (mouseX - NPRatingStartX) / (NPRatingFontSize + NPRatingPaddingSize) + 1;
    }
    if (ret > 5) {
        ret = 5;
    }
    return ret;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    oldRating = self.rating;
    isDragging = YES;
    
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(pos, self.bounds)) {
        self.rating = [self mousePosXToRating:pos.x];
    } else {
        self.rating = oldRating;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(pos, self.bounds)) {
        self.rating = [self mousePosXToRating:pos.x];
    } else {
        self.rating = oldRating;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    isDragging = NO;
    NSPoint pos = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    if (NSPointInRect(pos, self.bounds)) {
        int theRating = [self mousePosXToRating:pos.x];
        if (oldRating != theRating) {
            [[NPAppDelegate sharedInstance] changeRatingOfCurrentTrack:theRating];
            self.rating = theRating;
        } else {
            self.rating = oldRating;
        }
    } else {
        self.rating = oldRating;
    }
    [self setNeedsDisplay:YES];
}

@end


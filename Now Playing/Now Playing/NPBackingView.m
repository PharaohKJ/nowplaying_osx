//
//  NPBackingView.m
//  Now Playing
//
//  Created by numata on 2013/11/17.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPBackingView.h"
#import "NPAppDelegate.h"


@implementation NPBackingView {
    NSColor *color;
}

- (void)viewDidChangeBackingProperties
{
    [[NPAppDelegate sharedInstance] updateImageView];
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (!color) {
        color = [NSColor colorWithCalibratedWhite:0.96 alpha:1.0];
    }
    [color set];
    NSRectFill(dirtyRect);
}

@end


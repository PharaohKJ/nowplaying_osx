//
//  NSWindow+AccessoryView.h
//  Now Playing
//
//  Created by numata on 2013/11/17.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSWindow (AccessoryView)

-(void)addViewToTitleBar:(NSView*)viewToAdd atPosition:(CGPoint)pos;
-(CGFloat)heightOfTitleBar;

@end


//
//  NPPlayPositionView.h
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NPPlayPositionView : NSView

@property (readwrite, nonatomic) NSTimeInterval currentTime;
@property (readwrite, nonatomic) NSTimeInterval trackTime;

@end


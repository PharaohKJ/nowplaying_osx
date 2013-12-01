//
//  NPAppDelegate.h
//  Now Playing
//
//  Created by numata on 2013/05/09.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NPAppDelegate : NSObject <NSApplicationDelegate, NSSharingServiceDelegate, NSWindowDelegate, NSTextDelegate>

+ (NPAppDelegate *)sharedInstance;

@property (assign) IBOutlet NSWindow *window;

- (void)updateImageView;

- (void)changeRatingOfCurrentTrack:(int)rating;
- (void)setPlayerPosition:(NSTimeInterval)position;

@end


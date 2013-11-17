//
//  NPAppDelegate.h
//  Now Playing
//
//  Created by numata on 2013/05/09.
//  Copyright (c) 2013年 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NPAppDelegate : NSObject <NSApplicationDelegate, NSSharingServiceDelegate>

+ (NPAppDelegate *)sharedInstance;

@property (assign) IBOutlet NSWindow *window;
- (IBAction)copyTrackInfo:(id)sender;
- (IBAction)refreshTrackInfo:(id)sender;
- (IBAction)refreshAndCopy:(id)sender;
- (IBAction)makeTweet:(id)sender;

- (void)updateImageView;

@end


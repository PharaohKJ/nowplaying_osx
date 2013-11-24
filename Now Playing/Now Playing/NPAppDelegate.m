//
//  NPAppDelegate.m
//  Now Playing
//
//  Created by numata on 2013/05/09.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaLibrary/MediaLibrary.h>
#import "NSWindow+AccessoryView.h"
#import "NPLineView.h"
#import "NPRatingView.h"


@interface NPAppDelegate ()
@property (weak) IBOutlet NSView *albumArtworkView;
@property (weak) IBOutlet NSTextField *nameField;
@property (weak) IBOutlet NSView *mainView;
@property (weak) IBOutlet NSTextField *artistField;
@property (weak) IBOutlet NPLineView *lineView;
@property (weak) IBOutlet NPRatingView *ratingView;
@property (weak) IBOutlet NSButton *playButton;
@end


static NPAppDelegate *sInstance = nil;


@implementation NPAppDelegate {
    NSString *lastTweetStr;
    
    NSAppleScript *songInfoScript;
    NSAppleScript *albumArtworkScript;
    NSAppleScript *prevTrackScript;
    NSAppleScript *nextTrackScript;
    NSAppleScript *isPlayingScript;
    NSAppleScript *togglePlayScript;
    NSAppleScript *getCurrentPlaylistScript;
    
    NSImage *smallImage;
    NSImage *bigImage;
    
    CALayer *imageLayer;
}

+ (NPAppDelegate *)sharedInstance
{
    return sInstance;
}

- (NSAppleScript *)loadScriptWithName:(NSString *)scriptName
{
    NSError *error = nil;
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:scriptName.stringByDeletingPathExtension
                                             withExtension:scriptName.pathExtension];
    NSString *source = [NSString stringWithContentsOfURL:fileURL
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    NSDictionary *errorDict = nil;
    if (![script compileAndReturnError:&errorDict]) {
        NSLog(@"Failed to compile AppleScript: %@", scriptName);
    }
    return script;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    sInstance = self;
    
    self.albumArtworkView.wantsLayer = YES;
    CGSize imageViewSize = self.albumArtworkView.frame.size;
    imageLayer = [CALayer layer];
    imageLayer.bounds = CGRectMake(0, 0, imageViewSize.width, imageViewSize.height);
    imageLayer.position = CGPointMake(imageViewSize.width/2, imageViewSize.height/2);
    [self.albumArtworkView.layer addSublayer:imageLayer];
    
    [self.nameField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    
    // ウィンドウにボタンを追加
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 20)];
    button.buttonType = NSMomentaryLightButton;
    button.bezelStyle = NSRoundRectBezelStyle;
    button.title = @"Tweet";
    button.target = self;
    button.action = @selector(makeTweet:);
    [self.window addViewToTitleBar:button atXPosition:self.mainView.frame.size.width-80-8];
    
    // スクリプトの用意
    songInfoScript = [self loadScriptWithName:@"get_song_info.scpt"];
    albumArtworkScript = [self loadScriptWithName:@"get_album_artwork.scpt"];
    prevTrackScript = [self loadScriptWithName:@"goto_prev_song.scpt"];
    nextTrackScript = [self loadScriptWithName:@"goto_next_song.scpt"];
    isPlayingScript = [self loadScriptWithName:@"is_playing.scpt"];
    togglePlayScript = [self loadScriptWithName:@"toggle_play.scpt"];
    getCurrentPlaylistScript = [self loadScriptWithName:@"get_current_playlist.scpt"];

    // 再生中のトラックの変更通知受け取り
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(updateTrackInfo:) name:@"com.apple.iTunes.playerInfo" object:nil];

    [self refreshTrackInfo:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc removeObserver:self];
}

- (IBAction)copyTrackInfo:(id)sender
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard declareTypes:@[NSPasteboardTypeString] owner:nil];
    [pboard setString:lastTweetStr forType:NSPasteboardTypeString];
}

- (NSImage *)resizedImage:(NSImage *)sourceImage
{
    [sourceImage setScalesWhenResized:YES];
    
    NSSize viewSize = self.albumArtworkView.frame.size;
    
    NSSize imageSize = sourceImage.size;
    CGFloat aspect = imageSize.width / imageSize.height;
    NSSize newSize;
    if (aspect < 1.0) {
        newSize = NSMakeSize(viewSize.width * aspect, viewSize.height);
    } else {
        newSize = NSMakeSize(viewSize.width, viewSize.height / aspect);
    }

    if (![sourceImage isValid]) {
        return nil;
    }
    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage lockFocus];
    [sourceImage setSize:newSize];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [sourceImage drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height)
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0f];
    [newImage unlockFocus];
    return newImage;
}

- (void)changeTextFieldString:(NSTextField *)textField withString:(NSString *)string duration:(NSTimeInterval)duration
{
    textField.stringValue = string;
    /*[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:duration/2];
        [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
        [textField.animator setAlphaValue:0.0];
    } completionHandler:^{
        textField.stringValue = string;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:duration/2];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
            [textField.animator setAlphaValue:1.0];
        } completionHandler: ^{}];
    }];*/
}

- (IBAction)refreshTrackInfo:(id)sender
{
    if ([self isPlaying]) {
        [self.playButton setImage:[NSImage imageNamed:@"pause_button"]];
        [self.playButton setAlternateImage:[NSImage imageNamed:@"pause_button_pressed"]];
    } else {
        [self.playButton setImage:[NSImage imageNamed:@"play_button"]];
        [self.playButton setAlternateImage:[NSImage imageNamed:@"play_button_pressed"]];
    }

    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [songInfoScript executeAndReturnError:&errorInfo];
    NSArray *components = [desc.stringValue componentsSeparatedByString:@"/***/"];
    if (components.count >= 4) {
        NSString *name = components[0];
        NSString *artist = components[1];
        NSString *album = components[2];
        int rating = [components[3] intValue] / 20;

        self.ratingView.rating = rating;
        [self.ratingView setNeedsDisplay:YES];

        [self changeTextFieldString:self.nameField withString:name duration:0.7];
        [self changeTextFieldString:self.artistField withString:[NSString stringWithFormat:@"%@ - %@", artist, album] duration:0.7];

        //lastTweetStr = [NSString stringWithFormat:@"Now Playing: %@「%@」（%@）", artist, name, album];
        //lastTweetStr = [NSString stringWithFormat:@"Now Playing: %@ 📎%@ - %@ ", name, artist, album];
        lastTweetStr = [NSString stringWithFormat:@"Now Playing: %@ - %@ - %@", name, artist, album];
    }
    
    desc = [albumArtworkScript executeAndReturnError:&errorInfo];
    if (desc) {
        bigImage = [[NSImage alloc] initWithData:desc.data];
        smallImage = [self resizedImage:bigImage];
    } else {
        bigImage = [NSImage imageNamed:@"noartwork_big"];
        smallImage = [NSImage imageNamed:@"noartwork_small"];
    }
    [self updateImageView];
}

- (BOOL)isPlaying
{
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [isPlayingScript executeAndReturnError:&errorInfo];
    if ([desc.stringValue isEqualToString:@"playing"]) {
        return YES;
    }
    return NO;
}

- (NSString *)currentPlaylist
{
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [getCurrentPlaylistScript executeAndReturnError:&errorInfo];
    return desc.stringValue;
}

- (IBAction)refreshAndCopy:(id)sender
{
    [self refreshTrackInfo:self];
    [self copyTrackInfo:self];
}

- (IBAction)makeTweet:(id)sender
{
    NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];
    service.delegate = self;
    
    [service performWithItems:@[lastTweetStr]];
}

- (void)updateTrackInfo:(id)sender
{
    [self refreshTrackInfo:self];
}

- (NSWindow *)sharingService:(NSSharingService *)sharingService sourceWindowForShareItems:(NSArray *)items sharingContentScope:(NSSharingContentScope *)sharingContentScope
{
    return self.window;
}

- (void)updateImageView
{
    CGFloat scaleFactor = [[self window] backingScaleFactor];

    NSImage *theImage;
    if (scaleFactor == 1.0) {
        theImage = smallImage;
    } else {
        theImage = bigImage;
    }

    CGImageSourceRef cgImageSource = CGImageSourceCreateWithData((__bridge CFDataRef)theImage.TIFFRepresentation, NULL);
    CGImageRef cgImage =  CGImageSourceCreateImageAtIndex(cgImageSource, 0, NULL);
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:0.7];
    imageLayer.contents = (__bridge id)cgImage;
    [CATransaction commit];

    CGImageRelease(cgImage);
}

- (IBAction)backToPreviousSong:(id)sender
{
    NSDictionary *errorInfo = nil;
    [prevTrackScript executeAndReturnError:&errorInfo];
}

- (IBAction)gotoNextSong:(id)sender
{
    NSDictionary *errorInfo = nil;
    [nextTrackScript executeAndReturnError:&errorInfo];
}

- (IBAction)togglePlay:(id)sender
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSDictionary *errorInfo = nil;
        [togglePlayScript executeAndReturnError:&errorInfo];
    }];
}

- (void)windowDidResize:(NSNotification *)notification
{
    NSRect windowFrame = self.window.frame;
    NSRect lineViewFrame = self.lineView.frame;
    lineViewFrame.size.width = windowFrame.size.width - 5 * 2;
    self.lineView.frame = lineViewFrame;
}

- (void)changeRatingOfCurrentTrack:(int)rating
{
    NSLog(@"changeRatingOfCurrentTrack: %d", rating);

    NSString *currentPlaylistName = self.currentPlaylist;
    BOOL isPlaying = self.isPlaying;
    
    NSString *scriptName = @"change_rating.scpt";

    NSError *error = nil;
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:scriptName.stringByDeletingPathExtension
                                             withExtension:scriptName.pathExtension];
    NSString *source = [NSString stringWithContentsOfURL:fileURL
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    
    source = [source stringByReplacingOccurrencesOfString:@"__RATING__" withString:@(rating*20).stringValue];
    
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];

    NSDictionary *errorDict = nil;
    if (![script compileAndReturnError:&errorDict]) {
        NSLog(@"Failed to compile AppleScript: %@", scriptName);
    } else {
        NSDictionary *errorInfo = nil;
        [script executeAndReturnError:&errorInfo];
    }
    
    if (isPlaying) {
        [NSTimer scheduledTimerWithTimeInterval:0.1
                                         target:self
                                       selector:@selector(restartPlaying:)
                                       userInfo:currentPlaylistName
                                        repeats:NO];
    }
}

- (void)restartPlaying:(NSTimer *)timer
{
    if (self.isPlaying) {
        return;
    }
    
    NSString *playlistName = timer.userInfo;

    NSString *scriptName = @"change_playlist.scpt";
    
    NSError *error = nil;
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:scriptName.stringByDeletingPathExtension
                                             withExtension:scriptName.pathExtension];
    NSString *source = [NSString stringWithContentsOfURL:fileURL
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    source = [source stringByReplacingOccurrencesOfString:@"__PLAYLIST__" withString:playlistName];
    
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    
    NSDictionary *errorDict = nil;
    if (![script compileAndReturnError:&errorDict]) {
        NSLog(@"Failed to compile AppleScript: %@", scriptName);
    } else {
        NSDictionary *errorInfo = nil;
        [script executeAndReturnError:&errorInfo];
    }
}

@end


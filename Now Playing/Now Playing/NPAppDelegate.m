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
#import "NPRatingView.h"
#import "NPPlayPositionView.h"


@interface NPAppDelegate ()
@property (weak) IBOutlet NSView *albumArtworkView;
@property (weak) IBOutlet NSTextField *nameField;
@property (weak) IBOutlet NSView *mainView;
@property (weak) IBOutlet NSTextField *artistField;
@property (weak) IBOutlet NPRatingView *ratingView;
@property (weak) IBOutlet NSButton *playButton;
@property (weak) IBOutlet NSTextField *currentTimeLabel;
@property (weak) IBOutlet NSTextField *restTimeLabel;
@property (weak) IBOutlet NPPlayPositionView *playPositionView;
@property (unsafe_unretained) IBOutlet NSWindow *preferencesWindow;
@property (unsafe_unretained) IBOutlet NSTextView *tweetFormatView;
- (IBAction)showPreferencesPanel:(id)sender;
@end


static NPAppDelegate *sInstance = nil;


@implementation NPAppDelegate {
    NSAppleScript *songInfoScript;
    NSAppleScript *albumArtworkScript;
    NSAppleScript *prevTrackScript;
    NSAppleScript *nextTrackScript;
    NSAppleScript *isPlayingScript;
    NSAppleScript *togglePlayScript;
    NSAppleScript *getCurrentPlaylistScript;
    NSAppleScript *getPlayerPositionScript;
    
    NSImage *smallImage;
    NSImage *bigImage;
    
    CALayer *imageLayer;
    
    NSTimeInterval trackTime;
    
    NSTimer *playerPositionUpdateTimer;
    
    NSString *tweetFormat;
    
    NSString *lastArtistName;
    NSString *lastSongName;
    NSString *lastAlbumTitle;
    NSString *lastRatingStars;
    NSString *lastPlayedCountStr;
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
    
    tweetFormat = [[NSUserDefaults standardUserDefaults] stringForKey:@"Tweet Format"];
    if (!tweetFormat || tweetFormat.length == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Now Playing: @name@ - @artist@ - @album@" forKey:@"Tweet Format"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    self.tweetFormatView.font = [NSFont systemFontOfSize:13.0];
    [self.tweetFormatView setString:tweetFormat];
    
    self.albumArtworkView.wantsLayer = YES;
    CGSize imageViewSize = self.albumArtworkView.frame.size;
    imageLayer = [CALayer layer];
    imageLayer.bounds = CGRectMake(0, 0, imageViewSize.width, imageViewSize.height);
    imageLayer.position = CGPointMake(imageViewSize.width/2, imageViewSize.height/2);
    [self.albumArtworkView.layer addSublayer:imageLayer];
    
    [self.nameField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    
    self.currentTimeLabel.stringValue = @"0:00";
    self.restTimeLabel.stringValue = @"-0:00";
    
    // ウィンドウにボタンを追加
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 16)];
    button.buttonType = NSMomentaryLightButton;
    button.bezelStyle = NSRecessedBezelStyle;
    button.title = @"Tweet";
    button.target = self;
    button.action = @selector(makeTweet:);
    [self.window addViewToTitleBar:button atPosition:CGPointMake(self.mainView.frame.size.width-60-8, 3)];
    
    // スクリプトの用意
    songInfoScript = [self loadScriptWithName:@"get_song_info.scpt"];
    albumArtworkScript = [self loadScriptWithName:@"get_album_artwork.scpt"];
    prevTrackScript = [self loadScriptWithName:@"goto_prev_song.scpt"];
    nextTrackScript = [self loadScriptWithName:@"goto_next_song.scpt"];
    isPlayingScript = [self loadScriptWithName:@"is_playing.scpt"];
    togglePlayScript = [self loadScriptWithName:@"toggle_play.scpt"];
    getCurrentPlaylistScript = [self loadScriptWithName:@"get_current_playlist.scpt"];
    getPlayerPositionScript = [self loadScriptWithName:@"get_position.scpt"];

    // 再生中のトラックの変更通知受け取り
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(updateTrackInfo:) name:@"com.apple.iTunes.playerInfo" object:nil];

    [self refreshTrackInfo:self];
    
    // ウィンドウの表示
    [self.window makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc removeObserver:self];
}

- (NSString *)makeTweetString
{
    NSString *ret = tweetFormat;
    ret = [ret stringByReplacingOccurrencesOfString:@"@album@" withString:lastAlbumTitle];
    ret = [ret stringByReplacingOccurrencesOfString:@"@artist@" withString:lastArtistName];
    ret = [ret stringByReplacingOccurrencesOfString:@"@count@" withString:lastPlayedCountStr];
    ret = [ret stringByReplacingOccurrencesOfString:@"@name@" withString:lastSongName];
    ret = [ret stringByReplacingOccurrencesOfString:@"@rating@" withString:lastRatingStars];
    return ret;
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

- (void)updatePlayTimeInfoLabels
{
    NSTimeInterval playerPosition = [self playerPosition];
    NSTimeInterval restTime = trackTime - playerPosition;
    
    self.playPositionView.currentTime = playerPosition;
    [self.playPositionView setNeedsDisplay:YES];

    int hour = (int)(playerPosition / (60 * 60));
    playerPosition -= hour * 60 * 60;
    int min = (int)(playerPosition / 60);
    playerPosition -= min * 60;
    int sec = (int)(playerPosition + 0.5);
    
    if (hour > 0) {
        self.currentTimeLabel.stringValue = [NSString stringWithFormat:@"%d:%02d:%02d", hour, min, sec];
    } else {
        self.currentTimeLabel.stringValue = [NSString stringWithFormat:@"%d:%02d", min, sec];
    }
    
    hour = (int)(restTime / (60 * 60));
    restTime -= hour * 60 * 60;
    min = (int)(restTime / 60);
    restTime -= min * 60;
    sec = (int)(restTime + 0.5);

    if (hour > 0) {
        self.restTimeLabel.stringValue = [NSString stringWithFormat:@"-%d:%02d:%02d", hour, min, sec];
    } else {
        self.restTimeLabel.stringValue = [NSString stringWithFormat:@"-%d:%02d", min, sec];
    }
}

- (void)playPositionUpdateTimerProc:(id)sender
{
    [self updatePlayTimeInfoLabels];
}

- (IBAction)refreshTrackInfo:(id)sender
{
    if ([self isPlaying]) {
        [self.playButton setImage:[NSImage imageNamed:@"pause_button"]];
        [self.playButton setAlternateImage:[NSImage imageNamed:@"pause_button_pressed"]];
        
        if (!playerPositionUpdateTimer) {
            playerPositionUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                         target:self
                                                                       selector:@selector(playPositionUpdateTimerProc:)
                                                                       userInfo:nil
                                                                        repeats:YES];
        }
    } else {
        [self.playButton setImage:[NSImage imageNamed:@"play_button"]];
        [self.playButton setAlternateImage:[NSImage imageNamed:@"play_button_pressed"]];
        
        if (playerPositionUpdateTimer) {
            [playerPositionUpdateTimer invalidate];
            playerPositionUpdateTimer = nil;
        }
    }

    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [songInfoScript executeAndReturnError:&errorInfo];
    NSArray *components = [desc.stringValue componentsSeparatedByString:@"/***/"];
    if (components.count >= 6) {
        lastSongName = components[0];
        lastArtistName = components[1];
        lastAlbumTitle = components[2];
        int rating = [components[3] intValue] / 20;
        NSString *time = components[4];
        lastPlayedCountStr = components[5];
        NSArray *timeComponents = [time componentsSeparatedByString:@":"];
        int timeHour = 0;
        int timeMinute = 0;
        int timeSec = 0;
        if (timeComponents.count == 3) {
            timeHour = [timeComponents[0] intValue];
            timeMinute = [timeComponents[1] intValue];
            timeSec = [timeComponents[2] intValue];
        } else if (timeComponents.count == 2) {
            timeMinute = [timeComponents[0] doubleValue];
            timeSec = [timeComponents[1] doubleValue];
        } else {
            timeSec = [timeComponents[0] doubleValue];
        }
        trackTime = timeSec + timeMinute * 60.0 + timeHour * 60 * 60;
        self.playPositionView.trackTime = trackTime;
        [self updatePlayTimeInfoLabels];

        self.ratingView.rating = rating;
        [self.ratingView setNeedsDisplay:YES];

        self.nameField.stringValue = lastSongName;
        self.artistField.stringValue = [NSString stringWithFormat:@"%@ - %@", lastArtistName, lastAlbumTitle];
        
        if (rating > 0) {
            lastRatingStars = @"";
            for (int i = 0; i < rating; i++) {
                lastRatingStars = [lastRatingStars stringByAppendingString:@"★"];
            }
        } else {
            lastRatingStars = @"No Rating";
        }
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

- (NSTimeInterval)playerPosition
{
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *desc = [getPlayerPositionScript executeAndReturnError:&errorInfo];
    NSString *posStr = desc.stringValue;
    return posStr.doubleValue;
}

- (IBAction)makeTweet:(id)sender
{
    NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];
    service.delegate = self;
    
    [service performWithItems:@[ [self makeTweetString] ]];
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

- (void)setCurrentTime:(NSTimeInterval)time
{
    NSString *scriptName = @"set_position.scpt";

    NSError *error = nil;
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:scriptName.stringByDeletingPathExtension
                                             withExtension:scriptName.pathExtension];
    NSString *source = [NSString stringWithContentsOfURL:fileURL
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];
    
    source = [source stringByReplacingOccurrencesOfString:@"__POSITION__" withString:@(time).stringValue];
    
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    
    NSDictionary *errorDict = nil;
    if (![script compileAndReturnError:&errorDict]) {
        NSLog(@"Failed to compile AppleScript: %@", scriptName);
    } else {
        NSDictionary *errorInfo = nil;
        [script executeAndReturnError:&errorInfo];
    }
}

- (IBAction)showPreferencesPanel:(id)sender
{
    if (!self.preferencesWindow.isVisible) {
        [self.preferencesWindow center];
    }
    [self.preferencesWindow makeKeyAndOrderFront:self];
}

- (void)textDidChange:(NSNotification *)notification
{
    tweetFormat = self.tweetFormatView.string;
    [[NSUserDefaults standardUserDefaults] setObject:tweetFormat forKey:@"Tweet Format"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end


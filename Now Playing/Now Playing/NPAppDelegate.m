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
#import "NPITunesManager.h"
#import "NSImage+Utils.h"


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
    NPITunesManager *iTunesManager;
    
    NSImage *smallImage;
    NSImage *bigImage;
    CALayer *imageLayer;
    
    NSTimer         *playerPositionUpdateTimer;
    NSTimeInterval  trackTime;

    NSString    *lastArtistName;
    NSString    *lastSongName;
    NSString    *lastAlbumTitle;
    int         lastRating;
    NSString    *lastRatingStars;
    int         lastPlayedCount;

    NSString    *tweetFormat;
    BOOL        isChangingForRating;
}

+ (NPAppDelegate *)sharedInstance
{
    return sInstance;
}


#pragma mark - アプリケーション起動時の処理

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Singletonのサポート
    sInstance = self;
    
    // GUI部品の初期状態の設定
    tweetFormat = [[NSUserDefaults standardUserDefaults] stringForKey:@"Tweet Format"];
    if (!tweetFormat || tweetFormat.length == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Now Playing: @name@ - @artist@ - @album@" forKey:@"Tweet Format"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    self.tweetFormatView.font = [NSFont systemFontOfSize:13.0];
    [self.tweetFormatView setString:tweetFormat];
    
    self.albumArtworkView.wantsLayer = YES;
    CGSize imageViewSize = self.albumArtworkView.frame.size;
    self.albumArtworkView.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.88 alpha:1.0].CGColor;
    imageLayer = [CALayer layer];
    imageLayer.contentsGravity = kCAGravityResizeAspect;
    imageLayer.bounds = CGRectMake(0, 0, imageViewSize.width, imageViewSize.height);
    imageLayer.position = CGPointMake(imageViewSize.width/2, imageViewSize.height/2);
    [self.albumArtworkView.layer addSublayer:imageLayer];
    
    [self.nameField.cell setLineBreakMode:NSLineBreakByTruncatingTail];
    
    self.currentTimeLabel.stringValue = @"0:00";
    self.restTimeLabel.stringValue = @"-0:00";
    
    isChangingForRating = NO;
    
    // ウィンドウにボタンを追加
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 16)];
    [button.cell setControlSize:NSMiniControlSize];
    button.buttonType = NSMomentaryLightButton;
    button.bezelStyle = NSRecessedBezelStyle;
    button.title = @"Tweet";
    button.target = self;
    button.action = @selector(makeTweet:);
    [self.window addViewToTitleBar:button atPosition:CGPointMake(self.mainView.frame.size.width-60-8, 2.5)];
    
    // iTunes操作用のマネージャの用意
    iTunesManager = [NPITunesManager new];

    // 再生中のトラックの変更通知受け取り
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc addObserver:self selector:@selector(updateTrackInfo:) name:@"com.apple.iTunes.playerInfo" object:nil];

    // 最初の再生情報の取得
    [self updateTrackInfo:self];
    
    // ウィンドウの表示
    [self.window makeKeyAndOrderFront:self];
}


#pragma mark - アプリケーション終了時の処理

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSDistributedNotificationCenter *dnc = [NSDistributedNotificationCenter defaultCenter];
    [dnc removeObserver:self];
}


#pragma mark - トラック情報の取得

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
    return [sourceImage resizedImageForSize:newSize];
}

- (NSString *)timeStringForTimeInterval:(NSTimeInterval)time prefix:(NSString *)prefix
{
    int hour = (int)(time / (60 * 60));
    time -= hour * 60 * 60;
    int min = (int)(time / 60);
    time -= min * 60;
    int sec = (int)(time + 0.5);
    
    if (hour > 0) {
        return [NSString stringWithFormat:@"%@%d:%02d:%02d", prefix, hour, min, sec];
    } else {
        return [NSString stringWithFormat:@"%@%d:%02d", prefix, min, sec];
    }
}

- (void)updatePlayTimeInfoLabels
{
    NSTimeInterval playerPosition = iTunesManager.playerPosition;
    NSTimeInterval restTime = trackTime - playerPosition;
    
    self.playPositionView.currentTime = playerPosition;
    [self.playPositionView setNeedsDisplay:YES];

    self.currentTimeLabel.stringValue = [self timeStringForTimeInterval:playerPosition prefix:@""];
    self.restTimeLabel.stringValue = [self timeStringForTimeInterval:restTime prefix:@"-"];
}

- (void)playPositionUpdateTimerProc:(id)sender
{
    [self updatePlayTimeInfoLabels];
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

- (IBAction)updateTrackInfo:(id)sender
{
    if (isChangingForRating) {
        isChangingForRating = NO;
        return;
    }
    if (iTunesManager.isPlaying) {
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

    // 曲名
    lastSongName = iTunesManager.currentSongName;
    if (!lastSongName) {
        self.nameField.stringValue = @"-";
    } else {
        self.nameField.stringValue = lastSongName;
    }

    // アーティスト名、アルバム名
    lastArtistName = iTunesManager.currentArtistName;
    lastAlbumTitle = iTunesManager.currentAlbumTitle;
    if (!lastArtistName && !lastAlbumTitle) {
        self.artistField.stringValue = @"-";
    } else {
        self.artistField.stringValue = [NSString stringWithFormat:@"%@ - %@", lastArtistName, lastAlbumTitle];
    }

    // プレイ回数
    lastPlayedCount = iTunesManager.currentPlayedCount;
    
    // レーティング
    lastRating = iTunesManager.currentSongRating;
    self.ratingView.rating = lastRating;
    [self.ratingView setNeedsDisplay:YES];
    lastRatingStars = [iTunesManager starsStringFromRating:lastRating];
    if (!lastRatingStars || lastRatingStars.length == 0) {
        lastRatingStars = @"No Rating";
    }

    // トラックの長さ
    trackTime = iTunesManager.currentTrackTime;
    self.playPositionView.trackTime = trackTime;
    [self updatePlayTimeInfoLabels];

    // アルバムアートワーク
    bigImage = iTunesManager.currentArtworkImage;
    if (bigImage) {
        smallImage = [self resizedImage:bigImage];
    } else {
        bigImage = [NSImage imageNamed:@"noartwork_big"];
        smallImage = [NSImage imageNamed:@"noartwork_small"];
    }
    [self updateImageView];
    
    isChangingForRating = NO;
}


#pragma mark - 再生コントロール

- (IBAction)backToPreviousSong:(id)sender
{
    [iTunesManager gotoPreviousTrack];
}

- (IBAction)gotoNextSong:(id)sender
{
    [iTunesManager gotoNextTrack];
}

- (IBAction)togglePlay:(id)sender
{
    [iTunesManager togglePlay];
}

- (void)setPlayerPosition:(NSTimeInterval)position
{
    [iTunesManager setPlayerPosition:position];
}


#pragma mark - レーティングの変更

- (void)changeRatingOfCurrentTrack:(int)rating
{
    NSString *currentPlaylistName = iTunesManager.currentPlaylistName;
    BOOL wasPlaying = iTunesManager.isPlaying;
    
    [iTunesManager setCurrentSongRating:rating];

    if (wasPlaying) {
        isChangingForRating = YES;
        [NSTimer scheduledTimerWithTimeInterval:0.1
                                         target:self
                                       selector:@selector(restartPlaying:)
                                       userInfo:currentPlaylistName
                                        repeats:NO];
    }
}

- (void)restartPlaying:(NSTimer *)timer
{
    if (iTunesManager.isPlaying) {
        return;
    }
    
    NSString *playlistName = timer.userInfo;
    [iTunesManager setCurrentPlaylistWithName:playlistName];
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(doStartPlay:) userInfo:nil repeats:NO];
}

- (void)doStartPlay:(id)sender
{
    isChangingForRating = NO;
    [self togglePlay:self];
}


#pragma mark - 環境設定のサポート

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


#pragma mark - Twitter サポート

- (NSWindow *)sharingService:(NSSharingService *)sharingService sourceWindowForShareItems:(NSArray *)items sharingContentScope:(NSSharingContentScope *)sharingContentScope
{
    return self.window;
}

- (NSString *)makeTweetString
{
    NSString *ret = tweetFormat;
    ret = [ret stringByReplacingOccurrencesOfString:@"@album@" withString:lastAlbumTitle];
    ret = [ret stringByReplacingOccurrencesOfString:@"@artist@" withString:lastArtistName];
    ret = [ret stringByReplacingOccurrencesOfString:@"@count@" withString:@(lastPlayedCount).stringValue];
    ret = [ret stringByReplacingOccurrencesOfString:@"@name@" withString:lastSongName];
    ret = [ret stringByReplacingOccurrencesOfString:@"@rating@" withString:@(lastRating).stringValue];
    ret = [ret stringByReplacingOccurrencesOfString:@"@stars@" withString:lastRatingStars];
    return ret;
}

- (IBAction)makeTweet:(id)sender
{
    NSSharingService *service = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];
    service.delegate = self;
    
    [service performWithItems:@[ [self makeTweetString] ]];
}


@end


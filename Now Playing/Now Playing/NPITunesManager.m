//
//  NPITunesManager.m
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPITunesManager.h"
#import "NSAppleScript+Utils.h"


@implementation NPITunesManager {
    NSAppleScript *getPlayerPositionScript;
    NSAppleScript *getPlayerStateScript;

    NSAppleScript *getCurrentPlaylistScript;

    NSAppleScript *getAlbumTitleScript;
    NSAppleScript *getArtistNameScript;
    NSAppleScript *getArtworkScript;
    NSAppleScript *getPlayedCountScript;
    NSAppleScript *getSongNameScript;
    NSAppleScript *getSongRatingScript;
    NSAppleScript *getTrackTimeScript;

    NSAppleScript *gotoNextTrackScript;
    NSAppleScript *gotoPrevTrackScript;
    NSAppleScript *togglePlayScript;
}

- (id)init
{
    self = [super init];
    if (self) {
        // スクリプト（再生に関する情報）
        getPlayerPositionScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_position.scpt"];
        getPlayerStateScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_player_state.scpt"];

        // スクリプト（プレイリスト情報）
        getCurrentPlaylistScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_current_playlist.scpt"];

        // スクリプト（トラック情報の取得）
        getAlbumTitleScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_album_title.scpt"];
        getArtistNameScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_artist_name.scpt"];
        getArtworkScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_artwork.scpt"];
        getPlayedCountScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_played_count.scpt"];
        getSongNameScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_song_name.scpt"];
        getSongRatingScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_song_rating.scpt"];
        getTrackTimeScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"get_track_time.scpt"];

        // スクリプト（再生コントロール）
        gotoNextTrackScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"goto_next_track.scpt"];
        gotoPrevTrackScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"goto_prev_track.scpt"];
        togglePlayScript = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"toggle_play.scpt"];
    }
    return self;
}


#pragma mark - 再生に関する情報

- (BOOL)isPlaying
{
    NSString *state = [getPlayerStateScript executeAndReturnStringValue];
    return [state isEqualToString:@"playing"];
}

- (NSTimeInterval)playerPosition
{
    return [getPlayerPositionScript executeAndReturnDoubleValue];
}

- (void)setPlayerPosition:(NSTimeInterval)position
{
    NSAppleScript *script = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"set_position.scpt"
                                                                     replaceDict:@{ @"__POSITION__":@(position).stringValue }];
    [script execute];
}


#pragma mark - プレイリスト情報

- (NSString *)currentPlaylistName
{
    return [getCurrentPlaylistScript executeAndReturnStringValue];
}

- (void)setCurrentPlaylistWithName:(NSString *)name
{
    NSAppleScript *script = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"change_playlist.scpt"
                                                                     replaceDict:@{ @"__PLAYLIST__":name }];
    [script execute];
}


#pragma mark - トラック情報の取得

- (NSString *)currentAlbumTitle
{
    return [getAlbumTitleScript executeAndReturnStringValue];
}

- (NSString *)currentArtistName
{
    return [getArtistNameScript executeAndReturnStringValue];
}

- (NSImage *)currentArtworkImage
{
    NSData *imageData = [getArtworkScript executeAndReturnData];
    
    if (!imageData) {
        return nil;
    }
    return [[NSImage alloc] initWithData:imageData];
}

- (int)currentPlayedCount
{
    return [getPlayedCountScript executeAndReturnIntValue];
}

- (NSString *)currentSongName
{
    return [getSongNameScript executeAndReturnStringValue];
}

- (NSTimeInterval)currentTrackTime
{
    NSString *timeStr = [getTrackTimeScript executeAndReturnStringValue];
    NSArray *timeComponents = [timeStr componentsSeparatedByString:@":"];

    int hour = 0;
    int min = 0;
    int sec = 0;
    if (timeComponents.count == 3) {
        hour = [timeComponents[0] intValue];
        min = [timeComponents[1] intValue];
        sec = [timeComponents[2] intValue];
    } else if (timeComponents.count == 2) {
        min = [timeComponents[0] doubleValue];
        sec = [timeComponents[1] doubleValue];
    } else {
        sec = [timeComponents[0] doubleValue];
    }
    return sec + min * 60.0 + hour * 60 * 60;
}

- (int)currentSongRating
{
    return [getSongRatingScript executeAndReturnIntValue] / 20;
}

- (NSString *)starsStringFromRating:(int)rating
{
    NSString *ret = @"";
    for (int i = 0; i < rating; i++) {
        ret = [ret stringByAppendingString:@"★"];
    }
    return ret;
}


#pragma mark - トラック情報の変更

- (void)setCurrentSongRating:(int)rating
{
    NSAppleScript *script = [NSAppleScript scriptWithCompilingForSourceFileNamed:@"change_rating.scpt"
                                                                     replaceDict:@{ @"__RATING__":@(rating*20).stringValue }];
    [script execute];
}


#pragma mark - 再生コントロール

- (void)gotoNextTrack
{
    [gotoNextTrackScript execute];
}

- (void)gotoPreviousTrack
{
    [gotoPrevTrackScript execute];
}

- (void)togglePlay
{
    [togglePlayScript execute];
}

@end


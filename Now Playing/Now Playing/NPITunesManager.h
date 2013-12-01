//
//  NPITunesManager.h
//  Now Playing
//
//  Created by numata on 2013/12/01.
//  Copyright (c) 2013 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NPITunesManager : NSObject

// 再生に関する情報
- (BOOL)isPlaying;
- (NSTimeInterval)playerPosition;
- (void)setPlayerPosition:(NSTimeInterval)position;

// プレイリスト情報
- (NSString *)currentPlaylistName;
- (void)setCurrentPlaylistWithName:(NSString *)name;

// トラック情報の取得
- (NSString *)currentAlbumTitle;
- (NSString *)currentArtistName;
- (NSImage *)currentArtworkImage;
- (int)currentPlayedCount;
- (NSString *)currentSongName;
- (NSTimeInterval)currentTrackTime;
- (int)currentSongRating;

- (NSString *)starsStringFromRating:(int)rating;

// トラック情報の変更
- (void)setCurrentSongRating:(int)rating;

// 再生コントロール
- (void)gotoNextTrack;
- (void)gotoPreviousTrack;
- (void)togglePlay;

@end


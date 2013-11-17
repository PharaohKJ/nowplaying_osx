//
//  NPBackingView.m
//  Now Playing
//
//  Created by numata on 2013/11/17.
//  Copyright (c) 2013年 Sazameki and Satoshi Numata, Ph.D. All rights reserved.
//

#import "NPBackingView.h"
#import "NPAppDelegate.h"


@implementation NPBackingView

- (void)viewDidChangeBackingProperties
{
    [[NPAppDelegate sharedInstance] updateImageView];
}

@end


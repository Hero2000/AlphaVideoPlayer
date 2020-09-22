//
//  ViewController.m
//  AlphaVideoPlayer
//
//  Created by 尹一博 on 2020/9/22.
//  Copyright © 2020 Hero. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "LHVideoGiftAlphaVideoMetalView.h"
#import "LHVideoGiftAlphaVideoGLView.h"

#define ScreenSize [UIScreen mainScreen].bounds.size

@interface ViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (atomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CGSize videoSize;

@property (nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong) LHVideoGiftAlphaVideoMetalView *mtView;
@property (nonatomic, strong) LHVideoGiftAlphaVideoGLView *glView;



@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.clipsToBounds = NO;
    self.view.backgroundColor = [UIColor clearColor];
    [self play];
}

- (void)turnOnOrOffAudio
{
    float playerVolume = 1;
    AVAsset *avAsset = self.player.currentItem.asset;
    NSArray *audioTracks = [avAsset tracksWithMediaType:AVMediaTypeAudio];

    NSMutableArray *allAudioParams = [NSMutableArray array];
    for (AVAssetTrack *track in audioTracks) {
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        [audioInputParams setVolume:playerVolume atTime:kCMTimeZero];
        [audioInputParams setTrackID:[track trackID]];
        [allAudioParams addObject:audioInputParams];
    }
    AVMutableAudioMix *audioVolMix = [AVMutableAudioMix audioMix];
    [audioVolMix setInputParameters:allAudioParams];
    [self.player.currentItem setAudioMix:audioVolMix];
}

- (NSURL *)videoURL
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"test2" withExtension:@"mp4"];
    return url;
}

- (AVPlayer *)playerForVideoURL
{
    NSURL *url = [self videoURL];
    if (!url) {
        return nil;
    }
    return [AVPlayer playerWithURL:url];
}

- (CGSize)videoSize
{
    if (_videoSize.width == 0 && _videoSize.height == 0) {
        AVPlayer *tempPlayer = [self playerForVideoURL];
        NSArray *tracks = [tempPlayer.currentItem.asset tracksWithMediaType:AVMediaTypeVideo];
        AVAssetTrack *track = tracks.firstObject;
        CGFloat screenFactor = 1.0 / [UIScreen mainScreen].scale;
        CGSize naturalSize = track.naturalSize;
        _videoSize = CGSizeMake(screenFactor * naturalSize.width, screenFactor * naturalSize.height);
    }

    return _videoSize;
}

- (LHVideoGiftAlphaVideoGLView *)glView
{
    if (!_glView) {
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground || state == UIApplicationStateInactive) {
            return nil;
        }
        CGSize videoSize = self.videoSize;
        if (videoSize.width == 0 || videoSize.height == 0 || isnan(videoSize.width || isnan(videoSize.height))) {
            videoSize = CGSizeMake(2 * ScreenSize.width, ScreenSize.height);
        }
        CGFloat desiredWidth = ScreenSize.width;
        CGFloat desiredHeight = desiredWidth * videoSize.height /(.5f * videoSize.width);
        CGFloat top = ScreenSize.height - desiredHeight;
        CGRect viewFrame = CGRectMake(0, top, desiredWidth, desiredHeight);
        _glView = [[LHVideoGiftAlphaVideoGLView alloc] initWithFrame:viewFrame];
        _glView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_glView];
    }
    return _glView;
}

- (LHVideoGiftAlphaVideoMetalView *)mtView
{
    if (!_mtView) {
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground || state == UIApplicationStateInactive) {
            return nil;
        }
        CGSize videoSize = self.videoSize;
        if (videoSize.width == 0 || videoSize.height == 0 || isnan(videoSize.width || isnan(videoSize.height))) {
            videoSize = CGSizeMake(2 * ScreenSize.width, ScreenSize.height);
        }
        CGFloat desiredWidth = ScreenSize.width;
        CGFloat desiredHeight = desiredWidth * videoSize.height /(.5f * videoSize.width);
        CGFloat top = ScreenSize.height - desiredHeight;
        CGRect viewFrame = CGRectMake(0, top, desiredWidth, desiredHeight);
        NSLog(@"[%@] mtView width: %f  height: %f top: %f",NSStringFromClass(self.class),viewFrame.size.width,viewFrame.size.height,top);
        _mtView = [[LHVideoGiftAlphaVideoMetalView alloc] initWithFrame:viewFrame];
        _mtView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_mtView];
    }
    return _mtView;
}

- (void)setupVideoOutput
{
    NSDictionary *options = @{
                              (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                              (__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey : @YES
                              };
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:options];
    self.videoOutput.suppressesPlayerRendering = YES;
    [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:.1];
    [self.player.currentItem addOutput:self.videoOutput];
    
    [self createDisplayLink];
}

- (void)createDisplayLink
{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.preferredFramesPerSecond = 30;
    self.displayLink.paused = YES;
}



- (NSTimeInterval)duration
{
    return CMTimeGetSeconds(self.player.currentItem.asset.duration);
}


- (void)play
{
    __weak typeof(self) weakSelf = self;
    [self loadVideoWithCompletionBlock:^(BOOL success){
        if (success) {
            [weakSelf startPlayer];
        } else {
        }
    }];

}

#pragma mark - CADisplayLink Callback

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    if (!self.videoOutput) {
        return;
    }
    
    NSTimeInterval nextDisplayTime = sender.timestamp + sender.duration;
    CMTime itemTime = [self.videoOutput itemTimeForHostTime:nextDisplayTime];

    if ([self.videoOutput hasNewPixelBufferForItemTime:itemTime] && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        CVPixelBufferRef pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:itemTime
                                                 itemTimeForDisplay:nil];
        if (pixelBuffer) {
   
            if (YES) {
                [self.mtView displayPixelBuffer:pixelBuffer];
            }
            else {
                [self.glView displayPixelBuffer:pixelBuffer];
                CVPixelBufferRelease(pixelBuffer);
            }
        
            //NSTimeInterval timeInterval = CMTimeGetSeconds(itemTime);
        }
    }
}

- (void)loadVideoWithCompletionBlock:(void (^)(BOOL success))completionBlock
{
    self.player = [self playerForVideoURL];
    if (!self.player) {
        if (completionBlock) {
            completionBlock(NO);
        }
        return;
    }
    
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(videoDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.player.currentItem.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf setupVideoOutput];
                if (completionBlock) {
                    completionBlock(YES);
                }
            });
        }];
    });
}

- (void)videoDidPlayToEndTime:(NSNotification *)notification
{
    [self restart];
}


- (void)restart
{
    [self.player seekToTime:kCMTimeZero
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero];
    

}
- (void)startPlayer
{
    [self turnOnOrOffAudio];
    [self.player play];
    if (!self.displayLink) {
        [self createDisplayLink];
    }
    self.displayLink.paused = NO;
}


@end

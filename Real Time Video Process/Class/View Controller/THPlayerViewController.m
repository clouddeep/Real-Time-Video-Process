//
//  THPlayerViewController.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/19.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import "THPlayerViewController.h"
#import "APLEAGLView.h"

#import "THProfile.h"

static void *THPlayerItemStatusContext = &THPlayerItemStatusContext;

#define ONE_FRAME_DURATION 0.03

@interface THPlayerViewController () <AVPlayerItemOutputPullDelegate>
{
    dispatch_queue_t _myVideoOutputQueue;
    id _notificationToken;
    id _timeObserver;
}

@property (nonatomic, strong) APLEAGLView *playerView;

@property AVPlayerItemVideoOutput *videoOutput;
@property CADisplayLink *displayLink;

@end

@implementation THPlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    self.player = [[AVPlayer alloc] init];
    
    self.playerView = [[APLEAGLView alloc] initWithFrame:CGRectZero];
    self.view = self.playerView;
    
    // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.displayLink.paused = YES;
    
    // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    dispatch_queue_t queue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [[self videoOutput] setDelegate:self queue:queue];
    
    _myVideoOutputQueue = queue;
}

- (void)viewWillAppear:(BOOL)animated
{
    [self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:THPlayerItemStatusContext];
    [self addTimeObserverToPlayer];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.view.frame = [UIScreen mainScreen].bounds;
    
    [self.playerView setupGL];
    
    //    NSURL *url = [[NSBundle mainBundle] URLForResource:@"ElephantSeals" withExtension:@"mov"];
    [self setupPlaybackForAssset:self.asset];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self removeObserver:self forKeyPath:@"player.currentItem.status" context:THPlayerItemStatusContext];
    [self removeTimeObserverFromPlayer];
    
    [self.displayLink invalidate];
    self.displayLink = nil;
    
    [self.player pause];
    
    if (_notificationToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:_notificationToken name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
        _notificationToken = nil;
    }
    
    [super viewWillDisappear:animated];
}

- (UIView *)contentOverlayView
{
    return self.playerView;
}

#pragma mark - Playback setup

- (void)setupPlaybackForAssset:(AVURLAsset *)asset
{
    /*
     Sets up player item and adds video output to it.
     The tracks property of an asset is loaded via asynchronous key value loading, to access the preferred transform of a video track used to orientate the video while rendering.
     After adding the video output, we request a notification of media change in order to restart the CADisplayLink.
     */
    
    // Remove video output from old item, if any.
    [[self.player currentItem] removeOutput:self.videoOutput];
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    //    AVAsset *asset = item.asset;
    
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        
        if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
            NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            if ([tracks count] > 0) {
                // Choose the first video track.
                AVAssetTrack *videoTrack = [tracks objectAtIndex:0];
                [videoTrack loadValuesAsynchronouslyForKeys:@[@"preferredTransform"] completionHandler:^{
                    
                    if ([videoTrack statusOfValueForKey:@"preferredTransform" error:nil] == AVKeyValueStatusLoaded) {
                        CGAffineTransform preferredTransform = [videoTrack preferredTransform];
                        
                        /*
                         The orientation of the camera while recording affects the orientation of the images received from an AVPlayerItemVideoOutput. Here we compute a rotation that is used to correctly orientate the video.
                         */
                        self.playerView.preferredRotation = -1 * atan2(preferredTransform.b, preferredTransform.a);
                        
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [item addOutput:self.videoOutput];
                            [self.player replaceCurrentItemWithPlayerItem:item];
                            [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
                            [self.player play];
                        });
                        
                    }
                    
                }];
            }
        }
        
    }];
    
}

#pragma mark - CADisplayLink Callback

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    /*
     The callback gets called once every Vsync.
     Using the display link's timestamp and duration we can compute the next time the screen will be refreshed, and copy the pixel buffer for that time
     This pixel buffer can then be processed and later rendered on screen.
     */
    CMTime outputItemTime = kCMTimeInvalid;
    
    // Calculate the nextVsync time which is when the screen will be refreshed next.
    CFTimeInterval nextVSync = ([sender timestamp] + [sender duration]);
    
    outputItemTime = [[self videoOutput] itemTimeForHostTime:nextVSync];
    
    if ([[self videoOutput] hasNewPixelBufferForItemTime:outputItemTime]) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [[self videoOutput] copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        
        [self.playerView displayPixelBuffer:pixelBuffer];
        
        if (pixelBuffer != NULL) {
            CFRelease(pixelBuffer);
        }
    }
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    [self restartDisplayLink];
}

- (void)restartDisplayLink
{
    self.displayLink.paused = NO;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == THPlayerItemStatusContext) {
        AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerItemStatusUnknown:
                break;
            case AVPlayerItemStatusReadyToPlay:
                [self setValidVideoPresentationSize];
                break;
            case AVPlayerItemStatusFailed:
                [self stopLoadingAnimationAndHandleError:self.player.currentItem.error];
                
                break;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setValidVideoPresentationSize
{
    self.playerView.presentationRect = self.player.currentItem.presentationSize;
}

- (void)stopLoadingAnimationAndHandleError:(NSError *)error
{
    if (!error) return;
    
    NSString *cancelButtonTitle = NSLocalizedString(@"OK", @"Cancel button title for animation load error");
    
    NSString *title = [error localizedDescription];
    NSString *message = [error localizedFailureReason];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)addTimeObserverToPlayer
{
    /*
     Adds a time observer to the player to periodically refresh the time label to reflect current time.
     */
    if (_timeObserver)
        return;
    /*
     Use __weak reference to self to ensure that a strong reference cycle is not formed between the view controller, player and notification block.
     */
    __weak typeof(self) weakSelf = self;
    _timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 10) queue:dispatch_get_main_queue() usingBlock:
                     ^(CMTime time) {
//                         [weakSelf syncTimeLabel];
                     }];
}

- (void)removeTimeObserverFromPlayer
{
    if (_timeObserver)
    {
        [self.player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

#pragma mark - Orientation

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (THProfile.shared.deviceLandscapeOrientation == UIInterfaceOrientationLandscapeLeft) {
        return UIInterfaceOrientationMaskLandscapeLeft;
    } else {
        return UIInterfaceOrientationMaskLandscapeRight;
    }
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    if (THProfile.shared.deviceLandscapeOrientation == UIInterfaceOrientationLandscapeLeft) {
        return UIInterfaceOrientationLandscapeLeft;
    } else {
        return UIInterfaceOrientationLandscapeRight;
    }
}

@end

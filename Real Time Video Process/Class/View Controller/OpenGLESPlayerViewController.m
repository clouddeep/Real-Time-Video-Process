//
//  OpenGLESPlayerViewController.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2017/12/30.
//  Copyright © 2017年 Tuan Shou Cheng. All rights reserved.
//

#import "OpenGLESPlayerViewController.h"
@import AVKit;

#import "APLEAGLView.h"
#import "THProfile.h"

#define ONE_FRAME_DURATION 0.03

static void *AVPlayerItemStatusContext = &AVPlayerItemStatusContext;


@interface OpenGLESPlayerViewController () <AVPlayerItemOutputPullDelegate>
{
    AVPlayer *_player;
    dispatch_queue_t _myVideoOutputQueue;
    id _notificationToken;
    id _timeObserver;
    NSTimer *_panelTimer;
}

@property (weak, nonatomic) IBOutlet APLEAGLView *openGLView;
@property (strong, nonatomic) AVPlayer *player;
@property AVPlayerItemVideoOutput *videoOutput;
@property CADisplayLink *displayLink;

// Subviews
@property (weak, nonatomic) IBOutlet UIView *dismissView;
@property (weak, nonatomic) IBOutlet UIButton *dismissButton;

@property (weak, nonatomic) IBOutlet UIView *panelView;
@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UILabel *currentTime;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *remainingTime;

@property (nonatomic, getter=isPanelViewHidden) BOOL panelViewHidden;
@property (nonatomic, getter=isPanelViewHiddenAnimating) BOOL panelViewHiddenAnimating;

@property (nonatomic, getter=isVideoPlaying) BOOL videoPlay;

@end

@implementation OpenGLESPlayerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    _player = [[AVPlayer alloc] init];
    self.panelViewHiddenAnimating = NO;
    _panelViewHidden = NO;
    _videoPlay = NO;
    
    // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.displayLink.paused = YES;
    
    // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
    NSDictionary *pixBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixBuffAttributes];
    _myVideoOutputQueue = dispatch_queue_create("myVideoOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoOutput setDelegate:self queue:_myVideoOutputQueue];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:AVPlayerItemStatusContext];
    
    [self addTimeObserverToPlayer];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [[self openGLView] setupGL];
    
    [self setupPlaybackForAssset:self.asset];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self removeObserver:self forKeyPath:@"player.currentItem.status" context:AVPlayerItemStatusContext];
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

#pragma mark - Playback setup

- (void)setupPlaybackForAssset:(AVURLAsset *)asset
{
    /*
     Sets up player item and adds video output to it.
     The tracks property of an asset is loaded via asynchronous key value loading, to access the preferred transform of a video track used to orientate the video while rendering.
     After adding the video output, we request a notification of media change in order to restart the CADisplayLink.
     */
    
    // Remove video output from old item, if any.
    if (_player.currentItem) {
        [_player.currentItem removeOutput:self.videoOutput];
    }
    
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
                        self.openGLView.preferredRotation = -1 * atan2(preferredTransform.b, preferredTransform.a);
                        
                        // Video playback loop
                        [self addDidPlayToEndTimeNotificationForPlayerItem:item];
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [item addOutput:self.videoOutput];
                            [self.player replaceCurrentItemWithPlayerItem:item];
                            [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ONE_FRAME_DURATION];
                            [self.player play];
                            [self.playButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
                            [self addPanelViewHiddenTimer];
                            _videoPlay = YES;
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
    
    outputItemTime = [self.videoOutput itemTimeForHostTime:nextVSync];
    
    if ([self.videoOutput hasNewPixelBufferForItemTime:outputItemTime]) {
        CVPixelBufferRef pixelBuffer = NULL;
        pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:outputItemTime itemTimeForDisplay:NULL];
        
        [self.openGLView displayPixelBuffer:pixelBuffer];
        
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
    if (context == AVPlayerItemStatusContext) {
        AVPlayerStatus status = [change[NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerItemStatusUnknown:
                break;
            case AVPlayerItemStatusReadyToPlay:
                [self setValidVideoPresentationSize];
                [self setValidTimeSlider];
                break;
            case AVPlayerItemStatusFailed:
                [self stopLoadingAnimationAndHandleError:_player.currentItem.error];
                
                break;
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setValidVideoPresentationSize
{
    self.openGLView.presentationRect = _player.currentItem.presentationSize;
}

- (void)setValidTimeSlider
{
    self.slider.enabled = YES;
    double durations = CMTimeGetSeconds(_player.currentItem.duration);
    self.slider.maximumValue = durations;
    self.slider.value = 0;
    
    CIContext *c;
    CIImage *im;
    [c drawImage:im inRect:CGRectZero fromRect:CGRectZero];
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

- (void)addDidPlayToEndTimeNotificationForPlayerItem:(AVPlayerItem *)item
{
    if (_notificationToken)
        _notificationToken = nil;
    
    /*
     Setting actionAtItemEnd to None prevents the movie from getting paused at item end. A very simplistic, and not gapless, looped playback.
     */
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _notificationToken = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        // Simple item playback rewind.
        [_player seekToTime:kCMTimeZero];
        [_player play];
    }];
}

- (void)syncTimeLabel
{
    double seconds = CMTimeGetSeconds(_player.currentTime);
    double durations = CMTimeGetSeconds(_player.currentItem.duration);
    double remaining = durations - seconds;
    
    self.currentTime.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    self.currentTime.textAlignment = NSTextAlignmentCenter;
    
    self.currentTime.text = [self timeFormatString:seconds];
    
    self.remainingTime.textColor = [UIColor colorWithWhite:1.0 alpha:1.0];
    self.remainingTime.textAlignment = NSTextAlignmentCenter;
    NSString *remainingText = [NSString stringWithFormat:@"-%@", [self timeFormatString:remaining]];
    self.remainingTime.text = remainingText;
    
    [self.slider setValue:seconds animated:YES];
}

- (NSString *)timeFormatString:(double)seconds
{
    if (!isfinite(seconds)) {
        seconds = 0;
    }
    
    int secondsInt = round(seconds);
    int minutes = secondsInt/60;
    secondsInt -= minutes*60;
    
    NSString *time = [NSString stringWithFormat:@"%.2i:%.2i", minutes, secondsInt];
    
    return time;
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
    _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 10) queue:dispatch_get_main_queue() usingBlock:
                     ^(CMTime time) {
                         [weakSelf syncTimeLabel];
                     }];
}

- (void)removeTimeObserverFromPlayer
{
    if (_timeObserver)
    {
        [_player removeTimeObserver:_timeObserver];
        _timeObserver = nil;
    }
}

#pragma mark - Subviews

#define kCornerRadius 15

- (void)setDismissView:(UIView *)dismissView
{
    dismissView.layer.cornerRadius = kCornerRadius;
    dismissView.layer.masksToBounds = YES;
    
    _dismissView = dismissView;
}

- (void)setBottomView:(UIView *)bottomView
{
    bottomView.layer.cornerRadius = kCornerRadius;
    bottomView.layer.masksToBounds = YES;
    
    _bottomView = bottomView;
}

#pragma mark - Actions

- (IBAction)dismissPlayerView:(UIButton *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)videoPlay:(UIButton *)sender
{
    switch (self.player.timeControlStatus) {
        case AVPlayerTimeControlStatusPlaying:
            self.videoPlay = NO;
            break;
        case AVPlayerTimeControlStatusPaused:
            self.videoPlay = YES;
            break;
        default: // wait
            // do nothing
            break;
    }
}

- (IBAction)videoTimeChange:(UISlider *)sender
{
    // Remove timer when scrolling slider
    [self removePanelViewHiddenTimer];
    
    // Stop playing when scrolling slider
    if (self.isVideoPlaying) {
        self.videoPlay = NO;
    }
    
    // Set player to new time when user don't scroll the slider
    if (!sender.isTracking) {
        float value = sender.value;
        CMTime time = CMTimeMakeWithSeconds(value, 1);
        __weak typeof(self) weakSelf = self;
        [self.player seekToTime:time completionHandler:^(BOOL finished) {
            weakSelf.videoPlay = YES;
        }];
        // Add timer when scrolling ended
        [self addPanelViewHiddenTimer];
    }
}

- (IBAction)handlePanelViewDisplay:(UITapGestureRecognizer *)sender
{
    self.panelViewHidden = !self.isPanelViewHidden;
}

- (void)setVideoPlay:(BOOL)videoPlay
{
    if (videoPlay) {
        [self.player play];
        self.displayLink.paused = NO;
        [self.playButton setImage:[UIImage imageNamed:@"btn_pause"] forState:UIControlStateNormal];
    } else {
        [self.player pause];
        self.displayLink.paused = YES;
        [self.playButton setImage:[UIImage imageNamed:@"btn_play"] forState:UIControlStateNormal];
    }
    _videoPlay = videoPlay;
}

#pragma mark - Panel View

- (void)setPanelViewHidden:(BOOL)panelViewHidden
{
    // Prevent from rapid touch
    if (self.isPanelViewHiddenAnimating) { return; }
    
    if (!panelViewHidden) {
        self.dismissView.hidden = NO;
        self.bottomView.hidden = NO;
    }
    
    self.panelViewHiddenAnimating = YES;
    [UIView animateWithDuration:0.5 animations:^{
        self.dismissView.alpha = panelViewHidden ? 0 : 1;
        self.bottomView.alpha = panelViewHidden ? 0 : 1;
    } completion:^(BOOL finished) {
        if (panelViewHidden) {
            self.dismissView.hidden = YES;
            self.bottomView.hidden = YES;
            [self removePanelViewHiddenTimer];
        } else {
            [self addPanelViewHiddenTimer];
        }
        self.panelViewHiddenAnimating = NO;
    }];
    
    _panelViewHidden = panelViewHidden;
}

- (void)addPanelViewHiddenTimer
{
    __weak typeof(self) weakself = self;
    _panelTimer = [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        if (!weakself) { return; }
        
        weakself.panelViewHidden = YES;
    }];
}

- (void)removePanelViewHiddenTimer
{
    if (_panelTimer) {
        [_panelTimer invalidate];
        _panelTimer = nil;
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

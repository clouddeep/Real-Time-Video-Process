//
//  ViewController.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2017/12/26.
//  Copyright © 2017年 Tuan Shou Cheng. All rights reserved.
//

@import AVKit;
@import VideoToolbox;
@import CoreFoundation;
@import MetalKit;
#import "MainViewController.h"
#import "OpenGLESPlayerViewController.h"
#import "THOrientationNavigationController.h"
#import "THPlayerViewController.h"

#import "TheiaVideoCell.h"

#import "THProfile.h"

#define kVideoCell @"theia video cell"

#define kExtension @"mov"

@interface MainViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSMutableArray *assetArray;
@property (strong, nonatomic) NSArray *titleArray;
@property (strong, nonatomic) NSArray *descriptionArray;
@property (strong, nonatomic) NSArray *thumbnailArray;

@end

@implementation MainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"threal_mark"]];
        
    self.assetArray = [NSMutableArray array];
    
    [self loadDataAsync];
}

#pragma mark - Actions

- (IBAction)pickVideoOrientation:(UIBarButtonItem *)sender
{
    NSString *cancelTitle = @"Cancel";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *rightAction = [UIAlertAction actionWithTitle:@"Landscape Right" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        THProfile.shared.deviceLandscapeOrientation = UIDeviceOrientationLandscapeRight;
    }];
    UIAlertAction *leftAction = [UIAlertAction actionWithTitle:@"Landscape Left" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        THProfile.shared.deviceLandscapeOrientation = UIDeviceOrientationLandscapeLeft;
    }];

    [alert addAction:cancelAction];
    [alert addAction:rightAction];
    [alert addAction:leftAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Data Loading

- (void)loadDataAsync
{
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t groupQueue = dispatch_queue_create("group queue", 0);
    
    [self loadAllVideosWithGroup:group];
    
    dispatch_group_notify(group, groupQueue, ^{
        [self didFinishLoading];
    });
}

- (void)loadAllVideosWithGroup:(dispatch_group_t)group
{
    NSArray *allPath = [[NSBundle mainBundle] URLsForResourcesWithExtension:kExtension subdirectory:nil];
    
    for (NSURL *url in allPath) {
        dispatch_group_enter(group);
        
        AVURLAsset *asset = [AVURLAsset assetWithURL:url];
        [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            NSError *trackLoadingError = nil;
            
            if ([asset statusOfValueForKey:@"tracks" error:&trackLoadingError] == AVKeyValueStatusLoaded) {
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [self.assetArray addObject:asset];
                });
                
                dispatch_group_leave(group);
                
            } else {
                NSLog(@"trackLoadingError = %@", trackLoadingError);
            }
        }];
    }
}

- (void)didFinishLoading
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.assetArray sortUsingComparator:^NSComparisonResult(AVURLAsset *  _Nonnull obj1, AVURLAsset *  _Nonnull obj2) {
            if (CMTimeCompare(obj1.duration, obj2.duration) == -1) {
                return NSOrderedAscending;
            } else if (CMTimeCompare(obj1.duration, obj2.duration) == 1) {
                return NSOrderedDescending;
            } else {
                return NSOrderedSame;
            }
        }];
        [self.tableView reloadData];
    });
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OpenGLESPlayerViewController *vc = [self.storyboard instantiateViewControllerWithIdentifier:@"OpenGLESPlayerViewController"];
//    THPlayerViewController *vc = [[THPlayerViewController alloc] init];
    THOrientationNavigationController *nc = [[THOrientationNavigationController alloc] initWithRootViewController:vc];
    vc.asset = self.assetArray[indexPath.row];
    
    [self presentViewController:nc animated:YES completion:nil];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.assetArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    TheiaVideoCell *cell = [tableView dequeueReusableCellWithIdentifier:kVideoCell forIndexPath:indexPath];
    
    cell.titleLabel.text = self.titleArray[0];
    cell.descriptionLabel.text = self.descriptionArray[0];
    // If you have any thumbnail image, uncommet this line.
//    [cell setThumbnailImage:self.thumbnailArray[indexPath.row]];
    
    AVURLAsset *asset = self.assetArray[indexPath.row];
    [cell setVideoTimeWithSeconds:CMTimeGetSeconds(asset.duration)];
    
    /*
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    
    CMTime actualTime = kCMTimeZero;
    CGImageRef cgImageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:&actualTime error:nil];
    UIImage *image = [UIImage imageWithCGImage:cgImageRef];
    cell.videoThumbnailImageView.image = image;*/
    
    // Use thumbnail image
    cell.videoThumbnailImageView.image = [UIImage imageNamed:self.thumbnailArray.firstObject];
    
    return cell;
}

#pragma mark - Private

- (void)setTableView:(UITableView *)tableView
{
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    _tableView = tableView;
}

- (NSArray *)titleArray
{
    if (!_titleArray) {
        _titleArray = @[@"Main title"];
    }
    return _titleArray;
}

- (NSArray *)descriptionArray
{
    if (!_descriptionArray) {
        _descriptionArray = @[@"Subtitle for anything"];
    }
    return _descriptionArray;
}

- (NSArray *)thumbnailArray
{
    if (!_thumbnailArray) {
        _thumbnailArray = @[@"thumbnail_image_01"];
    }
    return _thumbnailArray;
}

@end

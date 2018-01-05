//
//  THProfile.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/4.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import "THProfile.h"

@implementation THProfile

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    static THProfile *_instance;
    dispatch_once(&onceToken, ^{
        _instance = [[THProfile alloc] init];
    });
    return _instance;
}

- (void)setDeviceLandscapeOrientation:(UIDeviceOrientation)deviceLandscapeOrientation
{
    if (deviceLandscapeOrientation == UIDeviceOrientationLandscapeLeft ||
        deviceLandscapeOrientation == UIDeviceOrientationLandscapeRight) {
        _deviceLandscapeOrientation = deviceLandscapeOrientation;
    } else {
        _deviceLandscapeOrientation = UIDeviceOrientationLandscapeLeft;
    }
}

@end

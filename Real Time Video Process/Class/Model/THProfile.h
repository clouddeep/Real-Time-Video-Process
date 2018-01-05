//
//  THProfile.h
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/4.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface THProfile : NSObject
+ (instancetype)shared;
@property (nonatomic) UIDeviceOrientation deviceLandscapeOrientation;
@end

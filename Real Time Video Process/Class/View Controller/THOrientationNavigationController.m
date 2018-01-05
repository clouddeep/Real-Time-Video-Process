//
//  THOrientationNavigationController.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/5.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import "THOrientationNavigationController.h"

@interface THOrientationNavigationController ()

@end

@implementation THOrientationNavigationController

- (BOOL)shouldAutorotate
{
    return [self.visibleViewController shouldAutorotate];
//    if ([self.visibleViewController respondsToSelector:@selector(shouldAutorotate)]) {
//        return [self.visibleViewController shouldAutorotate];
//    } else {
//        return YES;
//    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return [self.visibleViewController supportedInterfaceOrientations];
//    if ([self.visibleViewController respondsToSelector:@selector(supportedInterfaceOrientations)]) {
//        return [self.visibleViewController supportedInterfaceOrientations];
//    } else {
//        return UIInterfaceOrientationMaskPortrait;
//    }
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return [self.visibleViewController preferredInterfaceOrientationForPresentation];
//    if ([self.visibleViewController respondsToSelector:@selector(preferredInterfaceOrientationForPresentation)]) {
//        return [self.visibleViewController preferredInterfaceOrientationForPresentation];
//    } else {
//        return UIInterfaceOrientationPortrait;
//    }
}

@end

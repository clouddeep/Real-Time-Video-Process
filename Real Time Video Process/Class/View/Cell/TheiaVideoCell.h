//
//  TheiaVideoCell.h
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/3.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TheiaVideoCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *videoThumbnailImageView;
@property (weak, nonatomic) IBOutlet UIImageView *headerImageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UILabel *durationLabel;
@property (weak, nonatomic) IBOutlet UIView *labelView;

- (void)setVideoTimeWithSeconds:(NSTimeInterval)seconds;
- (void)setThumbnailImage:(NSString *)imageName;

@end

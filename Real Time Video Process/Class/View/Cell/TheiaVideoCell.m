//
//  TheiaVideoCell.m
//  Real Time Video Process
//
//  Created by Tuan Shou Cheng on 2018/1/3.
//  Copyright © 2018年 Tuan Shou Cheng. All rights reserved.
//

#import "TheiaVideoCell.h"

@implementation TheiaVideoCell

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.separatorInset = UIEdgeInsetsZero;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = self.headerImageView.bounds.size.width;
    self.headerImageView.layer.cornerRadius = width / 2.0;
    self.headerImageView.layer.masksToBounds = true;
}

- (void)setVideoTimeWithSeconds:(NSTimeInterval)seconds
{
    int sec = round(seconds);
    int minutes = sec/60;
    sec = sec - minutes*60;
    
    NSString *text = [NSString stringWithFormat:@"%.2i:%.2i", minutes, sec];
    self.durationLabel.text = text;
}

- (void)setThumbnailImage:(NSString *)imageName
{
    UIImage *image = [UIImage imageNamed:imageName];
    self.videoThumbnailImageView.image = image;
}

- (void)setLabelView:(UIView *)labelView
{
    labelView.layer.cornerRadius = 3;
    labelView.layer.masksToBounds = YES;
    
    _labelView = labelView;
}



@end

/*********************************************************/
/*                                                       *
 *                                                       *
 *   Follow your heart, but take your brain with you.    *
 *                                                       *
 *                                                       *
 *********************************************************/
//
//  LYFPreView.m
//  媒体捕捉
//
//  Created by 刘一峰 on 2017/8/16.
//  Copyright © 2017年 刘一峰. All rights reserved.
//

#import "LYFPreView.h"
@implementation LYFPreView

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [UIColor blackColor];
}
+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (void)setSession:(AVCaptureSession *)session {
    [(AVCaptureVideoPreviewLayer*)self.layer setSession:session];
    [(AVCaptureVideoPreviewLayer*)self.layer setVideoGravity:AVLayerVideoGravityResizeAspect];
}

@end

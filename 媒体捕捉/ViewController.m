//
//  ViewController.m
//  媒体捕捉
//
//  Created by 刘一峰 on 2017/8/16.
//  Copyright © 2017年 刘一峰. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "LYFPreView.h"
@interface ViewController ()
//捕捉会话
@property (nonatomic, strong) AVCaptureSession * capSession;
//捕捉设备
@property (nonatomic, strong) AVCaptureDevice *capDevice;
//捕捉设备的输入
@property (nonatomic, strong) AVCaptureDeviceInput *capDeviceInput;
//捕捉设备的输入
@property (nonatomic, strong) AVCaptureStillImageOutput * capVideoOutput;
//捕捉画面预览层
@property (weak, nonatomic) IBOutlet LYFPreView *preView;


@end

@implementation ViewController


- (AVCaptureSession *)capSession {
    if (!_capSession) {
        _capSession = [[AVCaptureSession alloc]init];
        //捕捉会话预设值 default
        _capSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    return _capSession;
}

- (AVCaptureDevice *)capDevice {
    if (!_capDevice) {
        _capDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return _capDevice;
}

- (AVCaptureDeviceInput *)capDeviceInput {
    if (!_capDeviceInput) {
        NSError * error;
        _capDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.capDevice error:&error];
    }
    return _capDeviceInput;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.preView];
    [self.preView setSession:self.capSession];
    if ([self.capSession canAddInput:self.capDeviceInput]) {
        [self.capSession addInput:self.capDeviceInput];
    }
    
    //将捕捉设备添加到Session会话前，需要提前判断一下当前会话是否支持提供的输出设备
    self.capVideoOutput = [[AVCaptureStillImageOutput alloc]init];
    if ([self.capSession canAddOutput:self.capVideoOutput]) {
        [self.capSession addOutput:self.capVideoOutput];
    }
    
    
    [self.capSession startRunning];
    
}

- (IBAction)photoClick:(id)sender {
    AVCaptureConnection * connect = [self.capVideoOutput connectionWithMediaType:AVMediaTypeVideo];
    id handle = ^(CMSampleBufferRef imageDataSampleBuffer,NSError * error){
        if (error) {
            NSLog(@"%@",error.description);
            return ;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [UIImage imageWithData:imageData];
        ALAssetsLibrary * library = [[ALAssetsLibrary alloc]init];
        [library writeImageToSavedPhotosAlbum:image.CGImage orientation:(NSInteger)image.imageOrientation completionBlock:^(NSURL *assetURL, NSError *error) {
            NSLog(@"%@",assetURL);
        }];
    };
    [self.capVideoOutput captureStillImageAsynchronouslyFromConnection:connect completionHandler:handle];
}




- (void)dealloc {
    if ([self.capSession isRunning]) {
        [self.capSession stopRunning];
    }
    self.capSession = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

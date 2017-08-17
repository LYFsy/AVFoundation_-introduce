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

@property (nonatomic, strong) AVCaptureDeviceInput * activityDevice;
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
        self.activityDevice = self.capDeviceInput;
    }
    
    //将捕捉设备添加到Session会话前，需要提前判断一下当前会话是否支持提供的输出设备
    self.capVideoOutput = [[AVCaptureStillImageOutput alloc]init];
    if ([self.capSession canAddOutput:self.capVideoOutput]) {
        [self.capSession addOutput:self.capVideoOutput];
    }
    
    
    [self.capSession startRunning];
    
}
#pragma mark 照相
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


#pragma mark -------begin:摄像头切换功能代码区----------------------

/*操作步骤：
 *1.根据媒体类型获取当前捕捉输入物理设备的总数(是否包含前置摄像头);
 *2.根据当前处于活跃状态的输入设备，获取未使用的输入设备，(比如当前采集画面的是后置摄像头，这一步需要获取前置摄像头)
 *3.获取未使用的输入设备后，需要将其装载到会话Session中，注意 beginConfiguration／commitConfiguration 这两个方法，成对出现，缺一不可。
 */


#pragma mark 摄像头转换
- (IBAction)switchCameras:(id)sender {
    if (![self canSwitchCameras]) {
        NSLog(@"不支持切换摄像头");
    }
    NSError * error;
    AVCaptureDevice * inActivityDevice = [self inActivityCamera];
    AVCaptureDeviceInput * deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inActivityDevice error:&error];
    if (deviceInput) {
        //开始装置设备。
        [self.capSession beginConfiguration];
        [self.capSession removeInput:self.activityDevice];
        if ([self.capSession canAddInput:deviceInput]) {
            [self.capSession addInput:deviceInput];
            self.activityDevice = deviceInput;
        }else {
            //切换失败时，重现将之前的设备添加到会话Session中。
            [self.capSession addInput:self.activityDevice];
        }
        
        //装置完毕后，需要提交此次的修改。
        [self.capSession commitConfiguration];
    }else {
        NSLog(@"切换摄像头出错");
    }
}

//是否可以切换摄像头
- (BOOL)canSwitchCameras {
    //1.获取当前媒体类型的设备数组
    NSUInteger count = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    return count > 1;
}

//根据指定的物理方位返回系统输入设备
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice * device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}
//获取当前未使用的输入设备(未激活的摄像头)
- (AVCaptureDevice *)inActivityCamera {
    AVCaptureDevice * device = nil;
    if ([self canSwitchCameras]) {
        if (self.activityDevice.device.position == AVCaptureDevicePositionBack) {
            //注意，这里正好时相反的AVCaptureDevicePosition。
            device = [self cameraWithPosition:AVCaptureDevicePositionFront];
        }else {
            device = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }
    }
    return device;
}
#pragma mark -------end:摄像头切换功能代码区----------------------


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

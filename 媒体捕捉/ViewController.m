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
@interface ViewController ()<UIGestureRecognizerDelegate>
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

@property (nonatomic, strong) AVCaptureConnection * connection;

@property (nonatomic, strong) AVCaptureDeviceInput * activityDevice;

//对焦View
@property (nonatomic, strong) UIView * focusView;
//曝光View
@property (nonatomic, strong) UIView *exposureView;

@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *singleTap;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *doubleTap;
@property (strong, nonatomic) IBOutlet UIPinchGestureRecognizer *pinchGesture;


//闪光灯or手电灯模式
@property(nonatomic, assign) AVCaptureFlashMode flashMode;
@property (nonatomic, assign) CGFloat lastEffectScale;
@property (nonatomic, assign) CGFloat beginEffectScale;

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

- (UIView *)focusView {
    if (!_focusView) {
        _focusView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 150, 150)];
        _focusView.layer.borderWidth = 1;
        _focusView.layer.borderColor = [UIColor greenColor].CGColor;
        _focusView.hidden = YES;
        [self.preView addSubview:_focusView];
    }
    return _focusView;
}

- (UIView *)exposureView {
    if (!_exposureView) {
        _exposureView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 150, 150)];
        _exposureView.layer.borderWidth = 1;
        _exposureView.layer.borderColor = [UIColor orangeColor].CGColor;
        _exposureView.hidden = YES;
        [self.preView addSubview:_exposureView];
    }
    return _exposureView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.lastEffectScale = self.beginEffectScale = 1.0;
    [self.view addSubview:self.preView];
    [self.preView setSession:self.capSession];
    if ([self.capSession canAddInput:self.capDeviceInput]) {
        [self.capSession addInput:self.capDeviceInput];
        self.activityDevice = self.capDeviceInput;
    }
    // 单击事件的处理在双击事件之后（）
    [self.singleTap requireGestureRecognizerToFail:self.doubleTap];
    
    //将捕捉设备添加到Session会话前，需要提前判断一下当前会话是否支持提供的输出设备
    self.capVideoOutput = [[AVCaptureStillImageOutput alloc]init];
    if ([self.capSession canAddOutput:self.capVideoOutput]) {
        [self.capSession addOutput:self.capVideoOutput];
    }
    
    
    [self.capSession startRunning];
    
}
#pragma mark 照相
- (IBAction)photoClick:(id)sender {
    self.connection = [self.capVideoOutput connectionWithMediaType:AVMediaTypeVideo];
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
    [self.capVideoOutput captureStillImageAsynchronouslyFromConnection:self.connection completionHandler:handle];
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



#pragma mark -------begin:对焦功能代码区-----------------------
//点击聚焦的方法
- (IBAction)focusClick:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.preView];
 
    [self showFocusBox:self.focusView atPoint:point];
    //首先需要将坐标转换成摄像头的坐标
    CGPoint capturePoint = [(AVCaptureVideoPreviewLayer *)self.preView.layer captureDevicePointOfInterestForPoint:point];
    
    [self focusAtPoint:capturePoint];
}
//显示聚焦框
- (void)showFocusBox:(UIView *)boxView atPoint:(CGPoint)point {
    boxView.center = point;
    boxView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        boxView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            boxView.hidden = YES;
            boxView.transform = CGAffineTransformIdentity;
        });
    }];
}
//判断当前设备是否支持对焦
- (BOOL)cameraSupportsTapFocus {
    return [self.activityDevice.device isFocusPointOfInterestSupported];
    
}

//摄像头进行对焦
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice * device = self.activityDevice.device;
    //判断当前输入设备是否可以对焦，并且支持自动对焦模式
    if ([self cameraSupportsTapFocus] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError * error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        }else {
            NSLog(@"对焦失败");
        }
    }
}



#pragma mark -------end:对焦功能代码区-------------------------

#pragma mark -------begin:曝光功能代码区-------------------------

//是否支持曝光功能呢
-(BOOL)camerasSupportsTaoExpose {
    return [self.activityDevice.device isExposurePointOfInterestSupported];
}

//根据传入的point，进行曝光，这其中对“adjustingExposure” 使用KVO进行监听。实现点击曝光并锁定的模式，之所以要间接实现这个功能，而没直接设置这个模式，是由于部分iOS设备还不支持这个模式。
- (void)exposeAtPoint:(CGPoint) point {
    AVCaptureDevice * device = self.activityDevice.device;
    if ([self camerasSupportsTaoExpose] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError * error;
        if ([device lockForConfiguration:&error]) {
            device.exposurePointOfInterest = point;
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            if([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:nil];
            }
            [device unlockForConfiguration];
        }else {
            NSLog(@"曝光失败");
        }
    }
}

//双击唤醒曝光功能
- (IBAction)showExposureClick:(UITapGestureRecognizer *)sender {
    CGPoint point = [sender locationInView:self.preView];
    //首先需要将坐标转换成摄像头的坐标
    CGPoint capturePoint = [(AVCaptureVideoPreviewLayer *)self.preView.layer captureDevicePointOfInterestForPoint:point];
    [self exposeAtPoint:capturePoint];
    [self showExposeView:self.exposureView atPoint:point];
}
//显示曝光框
- (void)showExposeView:(UIView *)boxView atPoint:(CGPoint) point {
    boxView.center = point;
    boxView.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        boxView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0);
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            boxView.hidden = YES;
            boxView.transform = CGAffineTransformIdentity;
        });
    }];
}

//监听摄像头的曝光属性adjustingExposure，是否由auto转换为lock
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"adjustingExposure"]) {
        AVCaptureDevice * device = (AVCaptureDevice *)object;
        if ([device isExposureModeSupported:AVCaptureExposureModeLocked] && !device.isAdjustingExposure) {
            [object removeObserver:self
                        forKeyPath:@"adjustingExposure"
                           context:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError * error;
                if ([device lockForConfiguration:&error]) {
                    device.exposureMode = AVCaptureExposureModeLocked;
                    [device unlockForConfiguration];
                }else {
                    NSLog(@"曝光失败");
                }
            });
        }
    }else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -------end:曝光功能代码区-------------------------



#pragma mark -------begin:闪光灯的方法---------------------


//判断是否支持闪光灯
- (BOOL)camerasHasFlash {
    return [self.activityDevice.device hasFlash];
}
//自动
- (IBAction)autoClick:(id)sender {
    if ([self camerasHasFlash]) {
        self.flashMode = AVCaptureFlashModeAuto;
    }
}
//开
- (IBAction)onClick:(id)sender {
    if ([self camerasHasFlash]) {
        self.flashMode = AVCaptureFlashModeOn;
    }
}
//关
- (IBAction)offClick:(id)sender {
    if ([self camerasHasFlash]) {
        self.flashMode = AVCaptureFlashModeOff;
    }
}
//设置当前输入设备指定的模式(闪光灯／手电灯)
- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    AVCaptureDevice * device = self.activityDevice.device;
    if (device.flashMode != flashMode &&
        [device isFlashModeSupported:flashMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"%@",error.description);
        }
    }
}

#pragma mark -------end:闪光灯方法---------------------

//通过手势调整摄像头的焦距
- (IBAction)updateScaleClick:(UIPinchGestureRecognizer *)sender {
    self.lastEffectScale = self.beginEffectScale * sender.scale;
    if (self.lastEffectScale < 1.0){
        self.lastEffectScale = 1.0;
    }
    //获取设备的最大缩放值
    CGFloat maxScale = [[self.capVideoOutput connectionWithMediaType:AVMediaTypeVideo] videoMaxScaleAndCropFactor];
    //我在这指定最多放大3倍.
    if (_lastEffectScale > 3) {
        _lastEffectScale = 3;
    }
    
    [UIView animateWithDuration:0.2 animations:^{
            self.preView.transform = CGAffineTransformMakeScale(_lastEffectScale, _lastEffectScale);

    }];
}
#pragma mark --------UIGestureRecognizerDelegate------

//捏合手势的代理方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
        //把最后获取的缩放值赋值给初始缩放值，用作下一次手势计算，否则将会出现屏幕抖动的情况
        self.beginEffectScale = self.lastEffectScale;
    }
    return YES;
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

//
//  DetailViewController.m
//  OpenCV_Demo14
//
//  Created by 國武　正督 on 2013/07/05.
//  Copyright (c) 2013年 Rz.inc. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "Utils.h"

@implementation DetailViewController {
    AVCaptureSession *session;
}

// ユーザーデフォルト（画像のソース選択結果）の呼び出し
//0:Library, 1:Camera ,2:Photo Album
@synthesize img_source;

// ネガポジ反転スイッチ
@synthesize invertSW;

//共通変数の定義
@synthesize effBufImage;
@synthesize fpsLabel;
@synthesize infoLabel01;
@synthesize infoLabel02;
@synthesize infoLabel03;
//@synthesize infoLabel04;

//MasterViewControllerで選択された変換処理クラス
@synthesize converter;

// ネガポジ反転インスタンス作成
id negapoji = [[NegaPosi alloc] init];

//FPS測定用変数
int countFPS;

//FPS測定用タイマー
NSTimer *timer = [[NSTimer alloc]init];

// 現在のキャプチャ入力デバイス
AVCaptureDevice *device;
AVCaptureDeviceInput *videoInput;


#pragma mark - Initialize
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // インフォメーションモニタラベル実装
    [self makeMonitorLabel];
    
    if (img_source == 1) {
        // リアルタイム変換時はReloadボタンで静止画をアルバムに保存する
        self.reloadBtn.title = NSLocalizedString(@"ReloadBtnTitle",@"ReloadBtnTitle");
        // changeCameraBtnは静止画変換時のみ実装
        [self makeChangeCameraBtn];
    }
    else {
        // ImgPickBtnは静止画変換時のみ実装
        [self makeImgPickBtn];
    }
    
    // ネガポジ反転スイッチ初期化
    invertSW = NO;
    self.invertBtn.tintColor = [UIColor grayColor];
    
    // スライダーの初期値を通知
    converter.gain = _levelSlider.value;
    infoLabel01.text = [NSString stringWithFormat:@"Slider value\n %.3f",_levelSlider.value];
    infoLabel02.text = [converter getGainFormat];

    // スライダーが変更されたとき
    [_levelSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
}

// MasterViewへ戻るときのイベント
- (void)viewDidDisappear:(BOOL)animated
{
//    NSLog(@"Back to Master");
    [session stopRunning];
    [timer invalidate];
    
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    //[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    [super viewDidDisappear:animated];
}


- (void)viewDidAppear:(BOOL)animated
{
    // img_source = 1 だったらリアルタイム変換モード
    if (img_source == 1) {
        
        // ビデオキャプチャの定義
//        AVCaptureDevice *d = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//        AVCaptureDeviceInput *cdi = [AVCaptureDeviceInput deviceInputWithDevice:d error:NULL];
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
        NSMutableDictionary *settings = [NSMutableDictionary dictionary];
        [settings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        
        //
        AVCaptureVideoDataOutput *cvdo = [[AVCaptureVideoDataOutput alloc] init];
        cvdo.videoSettings = settings;
        [cvdo setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
        [cvdo setAlwaysDiscardsLateVideoFrames:YES];
        
        //
        session = [[AVCaptureSession alloc] init];
        session.sessionPreset = AVCaptureSessionPreset640x480;
        [session commitConfiguration];
 
/*
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onOrientationChanged:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
*/
        // ビデオ入力のAVCaptureConnectionを取得
        AVCaptureConnection *captConnection = [cvdo connectionWithMediaType:AVMediaTypeVideo];
        captConnection.videoOrientation = [self videoOrientationFromDeviceOrientation:[UIDevice currentDevice].orientation];

        
        // ビデオのキャプチャを開始
        if ([session canAddInput:videoInput]) {
            [session addInput:videoInput];
            [session addOutput:cvdo];
            
            [session startRunning];
            

            [self startTimer];
        }
        else {
            // エラー処理
            NSLog(@"Input Err!!");
        }
        
    }
//    NSLog(@"viewDidAppear");
    [super viewDidAppear:animated];
}


#pragma mark - OpenCV
// キャプチャ中は常に呼び出される
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // イメージバッファの取得
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    // イメージバッファ情報の取得
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = (uint8_t*)CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // 画像の加工
    CGImageRef  cgImage;
    cgImage = CGBitmapContextCreateImage(cgContext);
    UIImage*  image = [UIImage imageWithCGImage:cgImage];
    UIImage*  effectImage;
    
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    effectImage = [self processWithOpenCV: image];
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    // 画像の表示
    self.imageView.image = effectImage;
    //self.imageView.image = image;
    
    //FPS測定
    countFPS++;
}

// UIImagePickerの呼び出し
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    effBufImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    [self dismissViewControllerAnimated:YES completion:^{
        
        // 画像の加工
        UIImage *effectImage = [self processWithOpenCV: effBufImage];
        
        // 加工した画像の表示
        self.imageView.image = effectImage;
        
        // 静止画をアルバムに保存
        //UIImageWriteToSavedPhotosAlbum(effectImage, nil, nil, nil);
        
        // インフォメーションラベル更新
        [self refreshInfoLabel];
    }];
}

// OpenCV関数を使って画像を変換します
- (UIImage*) processWithOpenCV: (UIImage*) cgImage
{
    
    // 正位置に回転
//    UIImage *img = [UIImage imageWithCGImage:cgImage.CGImage scale:1.0f orientation:UIImageOrientationRight];
    
    // 元となる画像の定義
    cv::Mat src_img = [Utils CVMatFromUIImage:cgImage];
    
    // 変換処理
    src_img = [converter convert:src_img];
    
    // ネガポジ反転有効時
    if (invertSW) {
        src_img = [negapoji convert:src_img];
    }
        
    //CGImageRef effectedCgImage = [Utils CGImageFromCVMat:src_img];
    UIImage *effectedImage = [Utils UIImageFromCVMat:src_img];
    
    // 何故か回転してしまうので、元に戻しています
    return [UIImage imageWithCGImage:effectedImage.CGImage scale:1.0f orientation:UIImageOrientationRight];
    //return effectedImage;
}


// 本体の向きを取得
- (AVCaptureVideoOrientation)videoOrientationFromDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation orientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationUnknown:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationFaceUp:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationFaceDown:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    return orientation;
}


#pragma mark - Button
// 右上のボタン（写真選択）を押したとき
- (void)photoButtonTouched
{
    // num = 0 or 2 だったら静止画変換モード
    // num = 3（キャンセル）だとアルバム
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    switch (img_source) {
        case 0: {
            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            break;
        }
        case 1: {
            //sourceType = UIImagePickerControllerSourceTypeCamera;
            //カメラはAVFoundationクラスで実装
            break;
        }
        case 2: {
            sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
            break;
        }
        case 3: {
            NSLog(@"Cancel");
            sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        }
            break;
    }
    
    // 使用可能かどうかチェックする
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        
        // イメージピッカーを作る
        UIImagePickerController*    picker;
        picker = [[UIImagePickerController alloc] init];
        picker.sourceType = sourceType;
        picker.delegate = self;
        
        // イメージピッカーを表示する
        [self presentViewController:picker animated:YES completion:NULL];
    }
    else {
        // エラー処理
        NSLog(@"Photo Err!!");
    }
}

// 右上のボタン（カメラのフロント/バック切り替え）を押したとき
- (void)changeCameraBtnTouched
{
    // フロントカメラを使っていたとき
    if(self.usingFrontCamera)
    {
        // デフォルトのカメラを使用
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        self.usingFrontCamera = NO;
    }

    // フロントカメラを使っていなかったとき
    else {
        // フロントカメラを検索
        for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if ([d position] == AVCaptureDevicePositionFront) {
                device = d;
                self.usingFrontCamera = YES;
                break;
            }
            else {
                // フロントカメラがなければデフォルトのカメラを使用
                device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
                self.usingFrontCamera = NO;
            }
        }        
    }
    // セッション切り替え
    [session stopRunning];
    [session beginConfiguration];
    [session removeInput:videoInput];
    videoInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    [session addInput:videoInput];
    [session commitConfiguration];
    [session startRunning];
}


// Reloadボタンで変換やり直し
- (IBAction)reloadBtn:(id)sender
{
    // ソースタイプ：静止画のとき
    if (img_source != 1) {
        
        // 画像の加工
        UIImage *effectImage = [self processWithOpenCV: effBufImage];
        
        //加工した画像の表示
        self.imageView.image = effectImage;
        
        // インフォメーションラベル更新
        [self refreshInfoLabel];
    }
    else {
        // リアルタイム変換時は静止画をアルバムに保存
        AudioServicesPlaySystemSound(1108);
        UIImageWriteToSavedPhotosAlbum(self.imageView.image, nil, nil, nil);
    }
}

// Invertボタンでネガポジ反転
- (IBAction)invertBtn:(id)sender
{
    // ネガポジ反転スイッチ切り替え
    if (invertSW)
    {
        invertSW = NO;
        self.invertBtn.tintColor = [UIColor magentaColor];
        // 色が変わらない..??
    }
    else
    {
        invertSW = YES;
        self.invertBtn.tintColor = [UIColor grayColor];
    }
}


#pragma mark - Timer

// インフォメーションラベル更新
- (void)refreshInfoLabel
{
    infoLabel03.text = [NSString stringWithFormat:@"Memory usage\n %@",[Utils convertByteToKB:[Utils getMemoryUsage]]];
}


// FPS測定開始(タイマー開始）
- (void)startTimer
{
    countFPS = 0;
    [timer invalidate];
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                             target:self
                                           selector:@selector(doTimer:)
                                           userInfo:nil
                                            repeats:YES
             ];
}

//FPS測定(結果画像が1sに何回表示されたか測定)
- (void)doTimer:(NSTimer *)timer
{
    NSLog(@"%d fps",countFPS);
    fpsLabel.text = [NSString stringWithFormat:@"%d fps", countFPS];
    countFPS = 0;
    
    // インフォメーションラベル更新
    [self refreshInfoLabel];
}


// スライダ値を取得
- (IBAction) sliderValueChanged:(UISlider *)sender {
    converter.gain = [sender value];
    infoLabel01.text = [NSString stringWithFormat:@"Slider value\n %.3f", [sender value]];
    infoLabel02.text = [converter getGainFormat];
}


#pragma mark - Label
// FPSモニタラベルを作成
- (void)makeMonitorLabel
{
    
    // FPSモニタラベル設置
    CGRect rect = CGRectMake(0, 0, 100, 20);
    fpsLabel = [[UILabel alloc]initWithFrame:rect];
    
    // FPSモニタラベルのテキストを設定
    fpsLabel.text = @"0 fps";
    
    // FPSモニタラベルのテキストのフォントを設定
    fpsLabel.font = [UIFont fontWithName:@"Helvetica" size:18];
    
    // FPSモニタラベルのテキストの色を設定
    fpsLabel.textColor = [UIColor yellowColor];
    
    // FPSモニタラベルのテキストの影を設定
    //fpsLabel.shadowColor = [UIColor grayColor];
    //fpsLabel.shadowOffset = CGSizeMake(1, 1);
    
    // FPSモニタラベルのテキストの位置を設定
    fpsLabel.textAlignment = NSTextAlignmentCenter;
    
    // FPSモニタラベルのテキストの行数設定
    fpsLabel.numberOfLines = 1; // 0の場合は無制限
    
    // FPSモニタラベルの背景色を設定
    fpsLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.4];
    
    // FPSモニタラベルをビューに追加
    [self.view addSubview:fpsLabel];
    
    
    // インフォメーションモニタラベル設置
    CGRect rect01 = CGRectMake(0, 20, 100, 40);
    infoLabel01 = [[UILabel alloc]initWithFrame:rect01];
    CGRect rect02 = CGRectMake(0, 60, 100, 60);
    infoLabel02 = [[UILabel alloc]initWithFrame:rect02];
    CGRect rect03 = CGRectMake(0, 120, 100, 40);
    infoLabel03 = [[UILabel alloc]initWithFrame:rect03];
    
    // インフォメーションモニタラベルの書式設定
    infoLabel01.text = [NSString stringWithFormat:@"Slider value\n  -  "];
    infoLabel01.textColor = [UIColor whiteColor];
    infoLabel01.shadowColor = [UIColor blackColor];
    infoLabel01.shadowOffset = CGSizeMake(1, 1);
    infoLabel01.font = [UIFont fontWithName:@"Helvetica" size:14];
    infoLabel01.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.4];
    infoLabel01.numberOfLines = 0; // 0の場合は無制限
    infoLabel02.text = [NSString stringWithFormat:@"Information\n  -  "];
    infoLabel02.textColor = infoLabel01.textColor;
    infoLabel02.shadowColor = infoLabel01.shadowColor;
    infoLabel02.shadowOffset = infoLabel01.shadowOffset;
    infoLabel02.font = infoLabel01.font;
    infoLabel02.backgroundColor = infoLabel01.backgroundColor;
    infoLabel02.numberOfLines = 0; // 0の場合は無制限
    infoLabel03.text = [NSString stringWithFormat:@"Memory usage\n %@",[Utils convertByteToKB:[Utils getMemoryUsage]]];
    infoLabel03.textColor = infoLabel01.textColor;
    infoLabel03.shadowColor = infoLabel01.shadowColor;
    infoLabel03.shadowOffset = infoLabel01.shadowOffset;
    infoLabel03.textAlignment = NSTextAlignmentRight;
    infoLabel03.font = infoLabel01.font;
    infoLabel03.backgroundColor = infoLabel01.backgroundColor;
    infoLabel03.numberOfLines = 0; // 0の場合は無制限
    
    [self.view addSubview:infoLabel01];
    [self.view addSubview:infoLabel02];
    [self.view addSubview:infoLabel03];

}

// システム標準画像を使ったボタン作成
- (void)makeImgPickBtn
{
        // 静止画変換時は画像ファイル選択ボタンを実装する
        UIBarButtonItem *imgPickBtn = [[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemCompose  // スタイル指定（使い方は不適切..)
                                       target:self  // デリゲートのターゲットを指定
                                       action:@selector(photoButtonTouched)  // ボタンが押されたときに呼ばれるメソッドを指定
                                       ];
        self.navigationItem.rightBarButtonItem = imgPickBtn;
}

// システム標準画像を使ったボタン作成
- (void)makeChangeCameraBtn
{
    // リアルタイム変換時はフロント or バックカメラ切り替えボタンを実装する
    UIBarButtonItem *changeCameraBtn = [[UIBarButtonItem alloc]
                                        initWithBarButtonSystemItem:UIBarButtonSystemItemCamera  // スタイル指定（使い方は不適切..)
                                        target:self  // デリゲートのターゲットを指定
                                        action:@selector(changeCameraBtnTouched)  // ボタンが押されたときに呼ばれるメソッドを指定
                                        ];
    self.navigationItem.rightBarButtonItem = changeCameraBtn;
}

#pragma mark - Error
//
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    NSLog(@"Memory Warning!");
}

@end

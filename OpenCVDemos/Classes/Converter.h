//
//  Converter.h
//  OpenCVDemos
//
//  Created by 中村 将 on 2013/07/19.
//  Copyright (c) 2013年 Rz.inc. All rights reserved.
//

#import "Utils.h"
#import <Foundation/Foundation.h>

@interface Converter : NSObject

@property float gain;

- (cv::Mat)convert:(cv::Mat)src_img;
- (NSString *) getGainFormat;
- (id)init;

@end

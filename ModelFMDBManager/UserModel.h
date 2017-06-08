//
//  UserModel.h
//  ModelFMDBManager
//
//  Created by zwb on 17/3/22.
//  Copyright © 2017年 HengSu Technology. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserModel : NSObject

@property (nonatomic, copy) NSString *string;
@property (assign) BOOL  flag;
@property (nonatomic, strong) NSArray *array;
@property (assign) NSNumber *xNumber;
@property (assign) NSInteger intrger;
@property (assign) double mDouble;

@end

//
//  ViewController.m
//  ModelFMDBManager
//
//  Created by zwb on 17/3/21.
//  Copyright © 2017年 HengSu Technology. All rights reserved.
//

#import "ViewController.h"

#import "ModelFMDBManager.h"
#import "UserModel.h"

@interface ViewController ()
@property (nonatomic, strong) UIView *topView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"首页";
    
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    self.topView = [UIView new];
    self.topView.backgroundColor = [UIColor redColor];
    self.topView.frame = CGRectMake(0, 64, width, 200);
    [self.view addSubview:self.topView];
    
    CGFloat btnPadding = 4;
    CGFloat btnHpadding = 5;
    CGFloat topViewBottom = self.topView.frame.size.height;
    CGFloat btnWidth = (width - 3 * btnPadding) / 4;
    CGFloat btnHeight = (height - 64 - 49 - topViewBottom - 2 * btnHpadding - 5) / 3;
    for (int i  = 0; i < 3; i ++) {
        for (int j = 0; j < 4; j ++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.backgroundColor = [UIColor orangeColor];
            [btn setTitle:[NSString stringWithFormat:@"%d%d",i,j] forState:UIControlStateNormal];
            btn.frame = CGRectMake((btnWidth + btnPadding) * j, 3 + topViewBottom + 64 + (btnHpadding + btnHeight) * i, btnWidth, btnHeight);
            [self.view addSubview:btn];
        }
    }
    
    
    ModelFMDBManager *manager = [ModelFMDBManager shareManager];
    // 关闭日志打印
//    manager.debugLogs = NO;
    
    UserModel *model = [UserModel new];
    [manager database:model fmdbType:ModelFMDBTypeCreate];
    
    UserModel *inserModel = [UserModel new];
    inserModel.string = @"测试";
    inserModel.flag = true;
    inserModel.array = @[@"我猜",@"人才啊",@"蠢"];
    inserModel.xNumber = @100;
    inserModel.intrger = 1000;
    
    NSMutableArray *inserModelArr = [NSMutableArray array];
    for (int index = 0 ; index <= 10; index ++ ) {
        [inserModelArr addObject:inserModel];
    }
    // 单个增
    __unused BOOL add = [manager operationDB:inserModel operationType:ModelFMDBOperationTypeAdd];
    // 数组增
//    __unused BOOL adds = [manager operationDB:inserModelArr operationType:ModelFMDBOperationTypeAdd];
    
    // 删除
//    __unused BOOL delete = [manager operationDB:model operationType:ModelFMDBOperationTypeDelete otherOperationString:@"WHERE xNumber = 101"];
    
    // 查询
//    __unused NSArray *query = [manager operationDB:model operationType:ModelFMDBOperationTypeQuery otherOperationString:@"WHERE intrger = '0001'"];
    
    // 改
//    __unused BOOL modify = [manager operationDB:inserModel operationType:ModelFMDBOperationTypeModify];
    
    // 清空
//    __unused BOOL clean = [manager database:model fmdbType:ModelFMDBTypeClean];
    
    // 删除库
//    __unused BOOL drop = [manager database:model fmdbType:ModelFMDBTypeDrop];
}
@end



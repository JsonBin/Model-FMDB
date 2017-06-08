//
//  ModelFMDBManager.h
//  ModelFMDBManager
//
//  Created by zwb on 17/3/21.
//  Copyright © 2017年 HengSu Technology. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 对数据表的操作类型

 - ModelFMDBOperationTypeAdd: 增加数据
 - ModelFMDBOperationTypeDelete: 删除数据 (有数据才删除，无数据时不删除)
 - ModelFMDBOperationTypeQuery: 查询数据
 - ModelFMDBOperationTypeModify: 修改数据 (如果不加限制条件，则为清空原数据，从新添加新数据)
 */
typedef NS_ENUM(NSUInteger, ModelFMDBOperationType) {
    ModelFMDBOperationTypeAdd,
    ModelFMDBOperationTypeDelete,
    ModelFMDBOperationTypeQuery,
    ModelFMDBOperationTypeModify,
};

/**
 对数据库/表的操作方法

 - ModelFMDBTypeCreate: 创建表
 - ModelFMDBTypeOpen: 打开数据表 (暂无此功能)
 - ModelFMDBTypeClose: 关闭数据表 (暂无此功能)
 - ModelFMDBTypeClean: 清除数据表 (清空数据，不删除定义)
 - ModelFMDBTypeDrop: 删除数据库
 */
typedef NS_ENUM(NSUInteger, ModelFMDBType) {
    ModelFMDBTypeCreate,
    ModelFMDBTypeOpen,
    ModelFMDBTypeClose,
    ModelFMDBTypeClean,
    ModelFMDBTypeDrop,
};

/**
 二次封装fmdb，通过model-sqlite对数据库进行操作
 */
@interface ModelFMDBManager : NSObject

/**
 是否打印日志，默认启动debug打印日志
 */
@property (assign) BOOL  debugLogs;

/**
 初始化

 @param name 本地项目内的数据库路径
 @return 初始化结果
 */
-(instancetype)initWithBundleName:(NSString *)name;

/**
 创建实例，项目唯一性 (使用工程名为db库名)

 @return 返回实例
 */
+(instancetype)shareManager;

/**
 创建实例，项目唯一性

 @param dbName 需要创建的db名字，如若不传，则使用工程名字命名
 @return 返回实例
 */
+(instancetype)shareManager:(NSString *)dbName;

/**
 创建数据表，通过传入的model来创建数据表(包括创建数据库，创建数据表，
 打开数据表，关闭数据表，删除数据表，删除数据库)

 @param model 传入的数据model
 @param fmdbType 需要操作的数据选项(建库，建表，打开表，关闭表，清除表，删除库)
 @return 相对应的操作选项是否操作成功
 */
-(BOOL)database:(id)model fmdbType:(ModelFMDBType)fmdbType;

/**
 对相应的数据表进行操作(使用增加时自动增加；
        使用删除时，默认删除所以数据；使用查询
        时，默认查询所有数据；使用修改时间时
        默认删除所以原数据，增加新数据)

 @param model 传入的对相应的数据表的model
 @param operationType 对数据表的操作类型(增、删、查、改)
 @return 返回相对应的操作结果
            add - 返回添加失败或成功(true or false)
            delete - 返回删除失败或成功(true or false)
            query - 返回查询的结果，对传入的model进行重新赋值，返回为对应的model类型
            modify - 返回修改失败或成功(true or false)
 */
-(id)operationDB:(id)model operationType:(ModelFMDBOperationType)operationType;


/**
 对相应的数据表进行操作(支持增、删、查、改)

 @param model 传入的对相应的数据表的model
 @param operationType 对数据表的操作类型(增、删、查、改)
 @param otherOperation 对数据表的操作的约束条件(如，需要删除数据表，
        可传入需要的约束，删除某一行或某一类型的数据；查询数据，需要查询
        的限制范围等，这里需要传入的为SQL语句；一般情况下，在删除，查找，修改的时候才
        传入限制条件，删除不传时就是全部删除，查找不传时全部查找，修改不
        传就是删除全部数据，重新插入新数据)
 @return 返回相对应的操作结果
                add - 返回添加失败或成功(true or false)
                delete - 返回删除失败或成功(true or false)，otherOperationString为nil时相当于清空数据表
                query - 返回查询的结果，对传入的model进行重新赋值，返回为对应的model类型
                modify - 返回修改失败或成功(true or false)
 */
-(id)operationDB:(id)model operationType:(ModelFMDBOperationType)operationType otherOperationString:(NSString *)otherOperation;

@end

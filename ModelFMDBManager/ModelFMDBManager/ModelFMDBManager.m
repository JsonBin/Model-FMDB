//
//  ModelFMDBManager.m
//  ModelFMDBManager
//
//  Created by zwb on 17/3/21.
//  Copyright © 2017年 HengSu Technology. All rights reserved.
//

#import "ModelFMDBManager.h"
#import "ModelFMDB.h"
#import <UIKit/UIKit.h>
#include <objc/runtime.h>

#if __has_include(<FMDB/FMDB.h>)
#import <FMDB/FMDB.h>
#else
#import "FMDB.h"
#endif

#define currentDB (FMDatabase *)[self.dbDictionary objectForKey:self.dbName]

@interface ModelFMDBManager()

@property (nonatomic, copy) NSString *dbName;
@property (nonatomic, strong) NSMutableDictionary *dbDictionary;

@end

static ModelFMDBManager *manager = nil;
@implementation ModelFMDBManager

#pragma mark -
#pragma mark - Public 公开方法

+(instancetype)shareManager {
    return [ModelFMDBManager shareManager:nil];
}

+(instancetype)shareManager:(NSString *)dbName {
    // 1. 获取数据库路径(长久保存在沙盒中)
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).lastObject;
    NSString *newDbName = nil;
    if (dbName && ![dbName isEqualToString:@""]) {
        newDbName = dbName;
    }else{
        // 获取工程名字
        NSDictionary *dictionary = [[NSBundle mainBundle] infoDictionary];
        NSString *projectName = [dictionary objectForKey:@"CFBundleDisplayName"];
        if (projectName && ![projectName isEqualToString:@""]) {
            newDbName = projectName;
        }else{
            newDbName = [dictionary objectForKey:@"CFBundleExecutable"];
        }
    }
    newDbName = newDbName.lowercaseString;
    
    // 2 判断文件是否存在，不存在则创建
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = YES;
    NSString *dbPath = [path stringByAppendingPathComponent:[newDbName stringByAppendingString:@".db"]];
    BOOL flag = [fileManager fileExistsAtPath:dbPath isDirectory:&isDirectory];
    if (!flag) {
        flag = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
        manager.dbDictionary = [NSMutableDictionary dictionary];
        manager.debugLogs = YES;
        if (flag) {
            ModelFMDB_main_safe((^(){
                FMDatabase *base = [FMDatabase databaseWithPath:dbPath];
                [manager.dbDictionary setValue:base forKey:newDbName];
                [manager showLogs:@"数据库(%@)创建成功",base];
            }));
        }
    });
    
    manager.dbName = newDbName;
    [manager showLogs:@"数据库路径为%@",dbPath];
    
    return manager;
}

-(BOOL)database:(id)model fmdbType:(ModelFMDBType)fmdbType {
    switch (fmdbType) {
        case ModelFMDBTypeCreate:
            // 建表
            return [self create:model autoClose:YES];
            break;
        case ModelFMDBTypeOpen:
            // 打开表
            return YES;
            break;
        case ModelFMDBTypeClose:
            // 关闭表
            return YES;
            break;
        case ModelFMDBTypeClean:
            // 清除表
            return [self truncate:model autoClose:YES];
            break;
        case ModelFMDBTypeDrop:
            // 删除库
            return [self dropDB];
            break;
    }
}

-(id)operationDB:(id)model operationType:(ModelFMDBOperationType)operationType {
    return [self operationDB:model operationType:operationType otherOperationString:nil];
}

-(id)operationDB:(id)model operationType:(ModelFMDBOperationType)operationType otherOperationString:(NSString *)otherOperation {
    switch (operationType) {
        case ModelFMDBOperationTypeAdd:  // 增(可一次增加多条数据)
        {
            BOOL add = [self insertTable:model otherOperation:otherOperation];
            return [NSNumber numberWithBool:add];
        }
            break;
        case ModelFMDBOperationTypeDelete:  // 删 (可一次删除多条数据)
        {
            BOOL delete = [self deleteTable:model otherOperation:otherOperation];
            return [NSNumber numberWithBool:delete];
        }
            break;
        case ModelFMDBOperationTypeQuery:  // 查 (只能查一个模型)
            return [self query:model otherLimit:otherOperation autoClose:YES];
            break;
        case ModelFMDBOperationTypeModify:  // 改 (只能改一个模型)
        {
            BOOL modify = [self modify:model otherLimit:otherOperation autoClose:YES];
            return [NSNumber numberWithBool:modify];
        }
            break;
    }
}

#pragma mark - 
#pragma mark - 对数据表的相应操作，可操作数组类型

-(BOOL) insertTable:(id)model otherOperation:(NSString *)operation {
    if ([model isKindOfClass:[NSArray class]] || [model isKindOfClass:[NSMutableArray class]]) {
        // 对数据模型组成的数组进行增加
        NSArray *modelArr = (NSArray *)model;
        BOOL flag = YES;
        for (id newModel in modelArr) {
            if (![self insert:newModel otherLimit:operation autoClose:NO]) {
                [self showLogs:@"添加数据(%@)入表时出错", newModel];
                flag = NO;
            }
        }
        // 处理完成关闭数据库
        if ([currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return flag;
    }else{
        return [self insert:model otherLimit:operation autoClose:YES];
    }
}

-(BOOL) deleteTable:(id)model otherOperation:(NSString *)operation {
    if ([model isKindOfClass:[NSArray class]] || [model isKindOfClass:[NSMutableArray class]]) {
        // 对数据模型组成的数组进行删除
        NSArray *modelArr = (NSArray *)model;
        BOOL flag = YES;
        for (id newModel in modelArr) {
            if (![self delete:newModel otherLimit:operation autoClose:NO]) {
                [self showLogs:@"删除数据(%@)时出错", newModel];
                flag = NO;
            }
        }
        // 处理完成关闭数据库
        if ([currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return flag;
    }else{
        return [self delete:model otherLimit:operation autoClose:YES];
    }
}

#pragma mark -
#pragma mark - Private 对数据库的封装方法
/**
 创建数据表

 @param model 对应的model
 @param autoClose 完成之后是否关闭数据库
 @return 创建是否成功
 */
-(BOOL)create:(id)model autoClose:(BOOL)autoClose{
    NSString *modelString = NSStringFromClass([model class]);
    [self showLogs:@"创建数据表%@",modelString];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if ([self dbIsExists:modelString autoClose:NO]) {
            if (autoClose && [currentDB close]) {
                 [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return YES;
        }
        // 没有表，创建
        BOOL create = [currentDB executeUpdate:[self createTableSQL:model]];
        [self showLogs:@"创建数据表(%@)%@",modelString,(create ? @"成功" : @"失败")];
        if (autoClose && [currentDB close]) {
             [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return create;
    }
     [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 查询数据库中是否存在为model的表

 @param table 需要创建的table
 @param autoClose 是否自动关闭
 @return 是否存在表
 */
-(BOOL)dbIsExists:(NSString *)table  autoClose:(BOOL)autoClose{
    [self showLogs:@"查询表(%@)是否存在",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        NSString *sql = @"select count(*) as 'count' from sqlite_master where type ='table' and name = ?";
        FMResultSet *result = [currentDB executeQuery:sql,table];
        NSInteger count = 0;
        // 全部遍历完毕，避免drop的时候出现还未遍历完成，处于select状态，使数据表处于lock状态
        while ([result next]) {
            count = [result intForColumn:@"count"];
        }
        if (count == 0) {
            [self showLogs:@"数据表(%@)不存在",table];
        }else{
            [self showLogs:@"查询表(%@)已存在",table];
        }
        // 操作完成关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return count == 0 ? NO : YES;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 清空数据表(因SQLite不支持truncate语句，因此采用下面方法)

 @param model 需要清除的数据表对应的model
 @param autoClose 完成是否自动关闭数据库
 @return 清空是否成功
 */
/*-(BOOL) truncate:(id)model autoClose:(BOOL)autoClose {
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"即将清除数据表(%@)",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if (![self dbIsExists:table autoClose:NO]) {
            [self showLogs:@"数据表(%@)不存在",table];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return NO;
        }
        BOOL truncate = [currentDB executeUpdate:@"TRUNCATE TABLE %@", table];
        [self showLogs:@"清除数据表(%@)%@",table,(truncate ? @"成功" : @"失败")];
        // 关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return truncate;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}*/

/**
 清空数据表(清除之后重新创建新表, 速度较快) - 这里为从新定义

 @param model 需要清除的数据表对应的model
 @param autoClose 完成是否自动关闭数据库
 @return 清空是否成功
 */
-(BOOL) truncate:(id)model autoClose:(BOOL)autoClose {
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"即将清除数据表(%@)",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if (![self dbIsExists:table autoClose:NO]) {
            [self showLogs:@"数据表(%@)不存在",table];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return NO;
        }
        NSString *sql = [NSString stringWithFormat:@"DROP TABLE %@",table];
        BOOL truncate = [currentDB executeUpdate:sql];
        // 清除之后重新创建新表
        if (truncate) {
            // 没有表，创建
            truncate = [currentDB executeUpdate:[self createTableSQL:model]];
            [self showLogs:@"清除数据表(%@)%@",table,(truncate ? @"成功" : @"失败")];
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return truncate;
        }
        if (truncate) {
             [self showLogs:@"清除数据表(%@)失败,但数据表已被移除",table];
        }else{
            [self showLogs:@"清除数据表(%@)失败",table];
        }
        // 关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return truncate;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 删除数据或表(删除数据表后可回滚，速度较慢)

 @param model 需要删除的数据对应的表的model
 @param otherLimit 其他SQL语句
 @param autoClose 完成之后是否关闭数据库
 @return 删除数据或表是否成功
 */
-(BOOL)delete:(id)model otherLimit:(NSString *)otherLimit autoClose:(BOOL)autoClose {
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"即将删除数据表(%@)",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if (![self dbIsExists:table autoClose:NO]) {
            [self showLogs:@"数据表(%@)不存在",table];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return NO;
        }
        NSArray *resultArr = [self query:model otherLimit:otherLimit autoClose:NO];
        if (resultArr && resultArr.count > 0) {
            NSString *sql  = [NSString stringWithFormat:@"DELETE FROM %@",table];
            if (otherLimit) {
                sql = [sql stringByAppendingFormat:@" %@",otherLimit];
            }
            BOOL delete = [currentDB executeUpdate:sql];
            [self showLogs:@"删除数据表(%@)%@",table,(delete ? @"成功" : @"失败")];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return delete;
        }
        [self showLogs:@"数据表(%@)数据为空，未进行删除操作",table];
        // 关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return NO;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 查询数据

 @param model 查询数据对应的model表
 @param otherLimit 其他SQL语句
 @param autoClose 完成之后是否关闭数据库
 @return 查询的结果，对应为model的数组
 */
-(NSArray *)query:(id)model otherLimit:(NSString *)otherLimit autoClose:(BOOL)autoClose {
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"查询数据表(%@)的数据",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if (![self dbIsExists:table autoClose:NO]) {
            [self showLogs:@"数据表(%@)不存在",table];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return nil;
        }
        NSString *sql  = [NSString stringWithFormat:@"SELECT * FROM %@",table];
        if (otherLimit) {
            sql = [sql stringByAppendingFormat:@" %@",otherLimit];
        }
        FMResultSet *result = [currentDB executeQuery:sql];
        NSMutableArray *modelArr = [NSMutableArray array];
        while ([result next]) {
            // 创建新的model
            id newModel = [[model class] new];
            
            unsigned int outCount = 0;
            Ivar *ivars = class_copyIvarList([newModel class], &outCount);
            for (int index = 0; index < outCount; index ++) {
                Ivar ivar = ivars[index];
                NSString *property = [NSString stringWithUTF8String:ivar_getName(ivar)];
                // 清除首位或末尾的下划线
                if ([property hasPrefix:@"_"]) {
                    property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
                }
                if ([property hasSuffix:@"_"]) {
                    property = [property stringByReplacingCharactersInRange:NSMakeRange(property.length-1, 1) withString:@""];
                }
                
                // 查询数据并存入model中
                id value = [result objectForColumnName:property];
                if ([value isKindOfClass:[NSString class]]) {
                    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
                    id dataResult = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([dataResult isKindOfClass:[NSDictionary class]] || [dataResult isKindOfClass:[NSMutableDictionary class]] || [dataResult isKindOfClass:[NSArray class]] || [dataResult isKindOfClass:[NSMutableArray class]]) {
                        [newModel setValue:dataResult forKey:property];
                    }else{
                        [newModel setValue:value forKey:property];
                    }
                }else{
                    [newModel setValue:value forKey:property];
                }
            }
            
            [modelArr addObject:newModel];
        }
        // 关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return modelArr;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return nil;
}

/**
 增加数据

 @param model 需要插入数据的model表
 @param otherLimit 其他SQL语句
 @param autoClose 完成之后是否关闭数据库
 @return 添加数据是否成功
 */
-(BOOL) insert:(id)model otherLimit:(NSString *)otherLimit autoClose:(BOOL)autoClose {
    if ([model isKindOfClass:[UIResponder class]]) {
        [self showLogs:@"插入数据非法,插入数据失败"];
        return NO;
    }
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"即将开始插入数据到数据表(%@)",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        // 这里处理数据分成三种情况处理(已有表，未有表，未有表创建表失败)
        
        // 1. 没有表，创建
        if (![self dbIsExists:table autoClose:NO]) {
            if ([self create:model autoClose:NO]) {
                BOOL add = [currentDB executeUpdate:[self createInserSQL:model otherLimit:otherLimit]];
                [self showLogs:@"插入数据表(%@)%@",table,(add ? @"成功" : @"失败")];
                // 关闭数据库
                if (autoClose && [currentDB close]) {
                    [self showLogs:@"关闭数据库(%@)成功",currentDB];
                }
                return add;
            }
            
            // 2.创建未成功，则插入失败
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return NO;
        }
        
        // 3. 已有表直接添加
        BOOL add = [currentDB executeUpdate:[self createInserSQL:model otherLimit:otherLimit]];
        [self showLogs:@"插入数据表(%@)%@",table,(add ? @"成功" : @"失败")];
        // 关闭数据库
        if (autoClose && [currentDB close]) {
            [self showLogs:@"关闭数据库(%@)成功",currentDB];
        }
        return add;
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 修改数据

 @param model 需要修改的数据表对应的model
 @param otherLimit 其他SQL语句
 @param autoClose 完成之后是否关闭数据库
 @return 修改数据是否成功
 */
-(BOOL) modify:(id)model otherLimit:(NSString *)otherLimit autoClose:(BOOL)autoClose {
    NSString *table = NSStringFromClass([model class]);
    [self showLogs:@"即将修改数据表(%@)的数据",table];
    if ([currentDB open]) {
        [self showLogs:@"打开数据库(%@)成功",currentDB];
        if (![self dbIsExists:table autoClose:NO]) {
            [self showLogs:@"数据表(%@)不存在",table];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return NO;
        }
        // 分为两种情况处理: 1. 未添加限制条件
        if (otherLimit == nil) {
            // 清空数据表，添加新数据
            BOOL modify = [self truncate:model autoClose:NO];
            if (modify) {
                modify = [self insert:model otherLimit:otherLimit autoClose:NO];
            }
            [self showLogs:@"修改数据表(%@)%@",table,(modify ? @"成功" : @"失败")];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return modify;
        }else{
            // 2. 添加了限制条件
            BOOL modify = [currentDB executeUpdate:[self createModifySQL:model otherLimit:otherLimit]];
            [self showLogs:@"修改数据表(%@)%@",table,(modify ? @"成功" : @"失败")];
            // 关闭数据库
            if (autoClose && [currentDB close]) {
                [self showLogs:@"关闭数据库(%@)成功",currentDB];
            }
            return modify;
        }
    }
    [self showLogs:@"打开数据库(%@)失败",currentDB];
    return NO;
}

/**
 删除数据库

 @return 删除是否成功
 */
-(BOOL) dropDB {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true).lastObject;
    NSString *sqlPath = [path stringByAppendingPathComponent:[self.dbName stringByAppendingString:@".db"]];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL drop = [manager removeItemAtPath:sqlPath error:nil];
    [self showLogs:@"删除数据库(%@)%@",currentDB,(drop ? @"成功" : @"失败")];
    return drop;
}

#pragma mark -
#pragma mark - SQL NSString
// 创建数据表sql
-(NSString *)createTableSQL:(id)model {
     [self showLogs:@"执行创建数据表SQL语句创建"];
    
    Class modelclass = [model class];
//    NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT , ",modelclass];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (", modelclass];
    
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(modelclass, &outCount);
    for (int index = 0; index < outCount; index ++) {
        Ivar ivar = ivars[index];
        NSString *property = [NSString stringWithUTF8String:ivar_getName(ivar)];
        if ([property hasPrefix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }
        if ([property hasSuffix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(property.length-1, 1) withString:@""];
        }
        
        if (index == 0) {
            [sql appendString:property];
        }else{
            [sql appendFormat:@", %@",property];
        }
    }
    [sql appendString:@")"];
    [self showLogs:@"创建SQL语句为:%@",sql];
    
    return sql;
}

// 创建插入数据的sql
-(NSString *)createInserSQL:(id)model otherLimit:(NSString *)otherLimit {
    [self showLogs:@"执行插入语句SQL创建"];
    
    Class modelclass = [model class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"INSERT OR REPLACE INTO %@ (", modelclass];
    
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(modelclass, &outCount);
    // 取model中的key
    for (int index = 0; index < outCount; index ++) {
        Ivar ivar = ivars[index];
        NSString *property = [NSString stringWithUTF8String:ivar_getName(ivar)];
        if ([property hasPrefix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }
        if ([property hasSuffix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(property.length-1, 1) withString:@""];
        }
        
        if (index == 0) {
            [sql appendString:property];
        }else{
            [sql appendFormat:@", %@",property];
        }
    }
    [sql appendFormat:@") VALUES ("];
    
    // 取model中的值
    for (int index = 0; index < outCount; index ++) {
        Ivar ivar = ivars[index];
        NSString *property = [NSString stringWithUTF8String:ivar_getName(ivar)];
        if ([property hasPrefix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }
        if ([property hasSuffix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(property.length-1, 1) withString:@""];
        }
        
        id value = [model valueForKey:property];
        // 防止空数据
        if (value == nil || [value isKindOfClass:[NSNull class]]) {
            value = @"";
        }
        // 将字典、数组包装
        if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]]) {
            /*NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:&error];
            value = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];*/
            value = [NSString stringWithFormat:@"%@",value];
        }
        if (index == 0) {
             // sql 语句中字符串需要单引号或者双引号括起来
            [sql appendFormat:@"%@",[value isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@"'%@'",value] : value];
        }else{
            [sql appendFormat:@", %@",[value isKindOfClass:[NSString class]] ? [NSString stringWithFormat:@"'%@'",value] : value];
        }
    }
    if (otherLimit && otherLimit.length > 0) {
        [sql appendFormat:@") %@",otherLimit];
    }else{
        [sql appendString:@");"];
    }
    
    [self showLogs:@"插入SQL语句为:%@",sql];
    
    return sql;
}

// 创建修改数据的sql
-(NSString *)createModifySQL:(id)model otherLimit:(NSString *)otherLimit {
    [self showLogs:@"开始执行创建修改SQL语句"];
    
    Class modelclass = [model class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE  %@  SET", modelclass];
    
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList(modelclass, &outCount);
    // 取model中的key
    for (int index = 0; index < outCount; index ++) {
        Ivar ivar = ivars[index];
        NSString *property = [NSString stringWithUTF8String:ivar_getName(ivar)];
        if ([property hasPrefix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@""];
        }
        if ([property hasSuffix:@"_"]) {
            property = [property stringByReplacingCharactersInRange:NSMakeRange(property.length-1, 1) withString:@""];
        }
        
        id value = [model valueForKey:property];
        // 防止空数据
        if (value == nil || [value isKindOfClass:[NSNull class]]) {
            value = @"";
        }
        
        if (index == 0) {
            [sql appendFormat:@"%@ = %@",property,([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]]) ? [NSString stringWithFormat:@"'%@'",value] : value];
        }else{
            [sql appendFormat:@", %@ = %@",property,([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSMutableDictionary class]] || [value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSMutableArray class]]) ? [NSString stringWithFormat:@"'%@'",value] : value];
        }
    }
    if (otherLimit && otherLimit.length > 0) {
        [sql appendFormat:@") %@",otherLimit];
    }
    
    [self showLogs:@"修改的SQL语句为:%@",sql];
    
    return sql;
}

#pragma mark -
#pragma mark - Debug Logs
// 打印日志
-(void) showLogs:(NSString *)log, ... {
    if (manager.debugLogs) {
        va_list args;
        va_start(args, log);
        
        NSMutableString *debug = [NSMutableString stringWithCapacity:log.length];
        [self formatString:log argumentsList:args intoString:debug];
        va_end(args);
        
        ModelFMDBLog(@"%@", debug);
    }
}

// fmdb 中的语句标准格式化
- (void)formatString:(NSString *)sql argumentsList:(va_list)args intoString:(NSMutableString *)string{
    
    NSUInteger length = [sql length];
    unichar last = '\0';
    for (NSUInteger i = 0; i < length; ++i) {
        id arg = nil;
        unichar current = [sql characterAtIndex:i];
        unichar add = current;
        if (last == '%') {
            switch (current) {
                case '@':
                    arg = va_arg(args, id);
                    break;
                case 'c':
                    // warning: second argument to 'va_arg' is of promotable type 'char'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                    arg = [NSString stringWithFormat:@"%c", va_arg(args, int)];
                    break;
                case 's':
                    arg = [NSString stringWithUTF8String:va_arg(args, char*)];
                    break;
                case 'd':
                case 'D':
                case 'i':
                    arg = [NSNumber numberWithInt:va_arg(args, int)];
                    break;
                case 'u':
                case 'U':
                    arg = [NSNumber numberWithUnsignedInt:va_arg(args, unsigned int)];
                    break;
                case 'h':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        //  warning: second argument to 'va_arg' is of promotable type 'short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithShort:(short)(va_arg(args, int))];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        // warning: second argument to 'va_arg' is of promotable type 'unsigned short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithUnsignedShort:(unsigned short)(va_arg(args, uint))];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'q':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'f':
                    arg = [NSNumber numberWithDouble:va_arg(args, double)];
                    break;
                case 'g':
                    // warning: second argument to 'va_arg' is of promotable type 'float'; this va_arg has undefined behavior because arguments will be promoted to 'double'
                    arg = [NSNumber numberWithFloat:(float)(va_arg(args, double))];
                    break;
                case 'l':
                    i++;
                    if (i < length) {
                        unichar next = [sql characterAtIndex:i];
                        if (next == 'l') {
                            i++;
                            if (i < length && [sql characterAtIndex:i] == 'd') {
                                //%lld
                                arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                            }
                            else if (i < length && [sql characterAtIndex:i] == 'u') {
                                //%llu
                                arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                            }
                            else {
                                i--;
                            }
                        }
                        else if (next == 'd') {
                            //%ld
                            arg = [NSNumber numberWithLong:va_arg(args, long)];
                        }
                        else if (next == 'u') {
                            //%lu
                            arg = [NSNumber numberWithUnsignedLong:va_arg(args, unsigned long)];
                        }
                        else {
                            i--;
                        }
                    }
                    else {
                        i--;
                    }
                    break;
                default:
                    // something else that we can't interpret. just pass it on through like normal
                    break;
            }
        }
        else if (current == '%') {
            // percent sign; skip this character
            add = '\0';
        }
        
        if (arg != nil) {
            if ([arg isKindOfClass:[NSString class]]) {
                [string appendString:arg];
            }else{
                [string appendFormat:@"%@",arg];
            }
        }
        else if (add == (unichar)'@' && last == (unichar) '%') {
            [string appendFormat:@"NULL"];
        }
        else if (add != '\0') {
            [string appendFormat:@"%C", add];
        }
        last = current;
    }
}

@end

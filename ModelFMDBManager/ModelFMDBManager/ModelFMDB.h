//
//  ModelFMDB.h
//  ModelFMDBManager
//
//  Created by zwb on 17/3/21.
//  Copyright © 2017年 HengSu Technology. All rights reserved.
//

#ifndef ModelFMDB_h
#define ModelFMDB_h

/**
 日志打印
 */
#ifdef DEBUG
#define ModelFMDBLog(...) NSLog(@"-----[FUNC:%s 行:%d] : %@-----",__func__,__LINE__,[NSString stringWithFormat:__VA_ARGS__])
#else
#define ModelFMDBLog(...)
#endif

/**
 主线程安全
 */
#define ModelFMDB_main_safe(block)\
if ([NSThread currentThread].isMainThread) {\
    block();\
} else {\
    dispatch_async(dispatch_get_main_queue(),block);\
}

#endif /* ModelFMDB_h */

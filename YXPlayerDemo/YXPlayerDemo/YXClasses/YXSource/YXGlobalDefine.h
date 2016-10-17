//
//  YXGlobalDefine.h
//  YXiOSPlayerTest
//
//  Created by 丁彦鹏 on 2016/9/30.
//  Copyright © 2016年 YunXi. All rights reserved.
//

#ifndef YXGlobalDefine_h
#define YXGlobalDefine_h

//#define YunXiService @"http://b.test.yunxi.tv/developer/api/" //测试服务器
#define YunXiService @"http://b.yunxi.tv/developer/api/" //正式服务器

#define Actitity_List @"activity-list" //获取活动
#define Activity_Info @"activity-info"
#define Livestream_Info @"livestream-info"
#define Comments_List @"comments-list" //获取评论
#define Save_Comment @"save-comment" //上传评论

//TODO:
#define YXBusinessAppId @""//@"企业APPID"
#define YXAccessKey @"" //填写自己公司的
#define YXSecretKey @"" //填写自己公司的

#define YXWildDogLivestream [YunXiService containsString:@"test"] ?@"https://wild-monkey-73114.wilddogio.com/livestream/" : @"https://yunxi.wilddogio.com/livestream/"



#endif /* YXGlobalDefine_h */

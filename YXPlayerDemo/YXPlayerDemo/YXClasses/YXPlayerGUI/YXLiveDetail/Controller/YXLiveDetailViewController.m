//
//  YXLiveDetailViewController.m
//  YXiOSPlayerTest
//
//  Created by 丁彦鹏 on 16/9/12.
//  Copyright © 2016年 YunXi. All rights reserved.
//

#import "YXLiveDetailViewController.h"
#import "YXGlobalDefine.h"
#import "YXPlayView.h"
#import "YXCommentView.h"
#import "YXTitleBar.h"
#import "YXCommentTableView.h"
#import "YXWebView.h"
#import "YXCalculateTimeLabel.h"

#import "YXLiveModel.h"
#import "YXLiveStream.h"
#import "YXNetWorking.h"
#import "YXModule.h"
#import "YXCommentModel.h"
#import "UIColor+YXExtension.h"
#import "WilddogSync.h"

#import "UIImage+YXExtension.h"
#import "NSTimer+YXExtension.h"
#import "UINavigationController+FDFullscreenPopGesture.h"

@interface YXLiveDetailViewController ()

@property (nonatomic, weak) YXPlayView *playView;
@property (nonatomic, weak) UIView *rePlayViewBottomCover; //回放时显示
@property (nonatomic, weak) UIButton *controlScreeBtn; //控制屏幕旋转
@property (nonatomic, weak) UISlider *slider;
@property (nonatomic, weak) YXCalculateTimeLabel *timeLab;
@property (nonatomic, strong) NSTimer *calculateTimer; //计时
@property (nonatomic, strong) NSTimer *noRepeatTimer;
@property (nonatomic, weak) YXTitleBar *titleBar;
@property (nonatomic, weak) YXCommentView *commentView;
@property (nonatomic, weak) UIButton *playBtn; //播放和暂停

@property (nonatomic, copy) NSArray<YXModule *> *modules; //模块
@property (nonatomic, copy) NSArray<NSString *> *moduleTitles;
@property (nonatomic, strong) YXLiveStream *liveStream;
@property (nonatomic, assign) NSInteger page; //评论的page
@property (nonatomic, strong) Wilddog *wilddogRef;
@property (nonatomic, assign) WilddogHandle wilddogHandle;
@property (nonatomic, assign) WilddogHandle wilddogRemoveHandle;
@property (nonatomic, assign) BOOL isStatusBarHidden;
@end

@implementation YXLiveDetailViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self setStatusBarHidden:true];
}

- (instancetype)init {
    self = [super init];
    self.fd_prefersNavigationBarHidden = YES;
    [self addSubviews];
    [self addConstraintsForSubviews];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"直播详情";
    self.view.backgroundColor = [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];
    self.edgesForExtendedLayout = UIRectEdgeBottom;
}

- (void)addSubviews {
    YXPlayView *playView = [[YXPlayView alloc] init];
    __weak typeof(self) weakSelf = self;
    playView.statusDidChangBlock =  ^(PLPlayerStatus status) {
        YXLiveDetailViewController *strongSelf = weakSelf;
        switch (status) {
            case PLPlayerStatusPlaying:
                strongSelf.playBtn.selected = YES;
                if (strongSelf.liveModel.streamStatus == 2 && strongSelf.playView.totalDuration.timescale != 0 && strongSelf.slider.maximumValue < 1.1) {
                    float maxValue = strongSelf.playView.totalDuration.value / strongSelf.playView.totalDuration.timescale;
                    if (maxValue != 0) {
                        strongSelf.slider.maximumValue = maxValue;
                        strongSelf.timeLab.totalTime = strongSelf.slider.maximumValue;
                    }
                }
                break;
            case PLPlayerStatusStopped:
                strongSelf.slider.value = 0;
                strongSelf.timeLab.currentTime = 1;
                strongSelf.playBtn.selected = NO;
            default:
                strongSelf.playBtn.selected = NO;
                break;
        }
    };
    [playView addTapTarget:self action:@selector(didTapPlayView)];
    [self.view addSubview:playView];
    self.playView = playView;
    
    UIButton *playBtn = [[UIButton alloc] init];
    [playBtn setImage:[UIImage imageNamed:@"detail_play_icon"] forState:UIControlStateNormal];
    [playBtn setImage:[UIImage imageNamed:@"detail_pause_icon"] forState:UIControlStateSelected];
    [playBtn addTarget:self action:@selector(didClickPlayBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
    self.playBtn = playBtn;
    
    UIView *rePlayViewBottomCover = [self createRePlayViewBottomCover];
    [self.view addSubview:rePlayViewBottomCover];
    self.rePlayViewBottomCover = rePlayViewBottomCover;
}

- (void)addConstraintsForSubviews {
    [self.playView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.height.equalTo(self.playView.mas_width).multipliedBy(0.56);
    }];
    
    [self.playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.playView);
        make.size.mas_equalTo(CGSizeMake(65, 65));
    }];
    
    [self.rePlayViewBottomCover mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.playView);
        make.height.equalTo(@33);
    }];
}

#pragma mark setter
- (void)setLiveModel:(YXLiveModel *)liveModel {
    _liveModel = liveModel;
    [self sendLiveStreamInfoRequest];
}

- (void)setModules:(NSArray<YXModule *> *)modules {
    _modules = modules;
    [self.titleBar removeFromSuperview];
    YXCommentView *commentView = [[YXCommentView alloc] init];
    __weak typeof(self) weakSelf = self;
    commentView.commentTableView.startLoadMoreData = ^{
        YXLiveDetailViewController *strongSelf = weakSelf;
        [strongSelf sendCommentListRequest];
    };
    self.commentView = commentView;
    NSMutableArray *views = [NSMutableArray arrayWithCapacity:self.moduleTitles.count];
    [views addObject:commentView];
    for (int i = 1; i < self.modules.count; ++i) {
        YXWebView *view = [YXWebView new];
        view.backgroundColor = [UIColor whiteColor];
        if (modules[i].html) {
            view.content = modules[i].html;//modules[i].editorValue;
        }
        [views addObject:view];
    }
    
    CGFloat titleH = self.moduleTitles.count <= 1 ? 0 : 45;
    YXTitleBar *titleBar = [YXTitleBar titleBarWithTitleArray:self.moduleTitles  Frame:CGRectZero titleH:titleH showDetaiViews:views];
    [self.view addSubview:titleBar];
    self.titleBar = titleBar;
    [titleBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.playView.mas_bottom);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];
}

- (void)setLiveStream:(YXLiveStream *)liveStream {
    _liveStream = liveStream;
    self.commentView.streamId = liveStream.ID;
    self.liveModel.liveStream = liveStream;
    self.playView.liveModel = self.liveModel;
    if (liveStream.status == 1) {
        [self showMessage:@"即将观看直播"];
    } else if(liveStream.status == 2) {
        [self showMessage:@"即将观看回播"];
        [self createCalculateTimer];
    } else {
        [self showMessage:@"直播还未开始"];
    }
    self.didUpdateStreamStatus(liveStream.status);
}

#pragma mark 网络请求
- (void)sendLiveStreamInfoRequest {
    __weak typeof(self) weakSelf = self;
    NSDictionary *para = @{ @"activityId":self.liveModel.liveId};
    [YXNetWorking postUrlString:YXLivestream_Info paramater:para success:^(id obj, NSURLResponse *response) {
        YXLiveDetailViewController *strongSelf = weakSelf;
        NSDictionary *data = obj[@"data"];
        NSDictionary *templateData = data[@"templateData"];
        //模块
        if (![templateData isKindOfClass:[NSNull class]]) {
            NSMutableArray *modules = [NSMutableArray array];
            NSMutableArray *titles = [NSMutableArray array];
            for (NSDictionary *dic in templateData[@"modules"]) {
                YXModule *module = [YXModule moduleWithDic:dic];
                if ([module.type isEqualToString:@"comment"]) {
                    //评论放在第一个
                    [modules insertObject:module atIndex:0];
                    [titles insertObject:module.name atIndex:0];
                } else {
                    [modules addObject:module];
                    [titles addObject:module.name];
                }
            }
            strongSelf.moduleTitles = titles;
            strongSelf.modules = modules;
        }
        if (strongSelf.moduleTitles.count == 0) {
            YXModule *module = [YXModule moduleWithDic:@{@"name":@"评论",@"type":@"comment"}];
            strongSelf.moduleTitles = @[module.name];
            strongSelf.modules = @[module];
        }
        
        strongSelf.liveStream = [YXLiveStream liveStreamWithDic:data[@"livestream"]];
        //获取评论
        [strongSelf sendCommentListRequest];
    } fail:^(NSError *error, NSString *errorMessage) {
        NSLog(@"errorMessage：%@", errorMessage);
    }];
    
}
- (void)sendCommentListRequest {
    self.page = 1;
    NSString *page = [NSString stringWithFormat:@"%ld",self.page];
    NSDictionary *para = @{@"lsId":self.liveStream.ID,
                           @"page":page};
    __weak typeof(self) weakSelf = self;
    [YXNetWorking postUrlString:YXComments_List paramater:para success:^(id obj, NSURLResponse *response) {
        YXLiveDetailViewController *strongSelf = weakSelf;
        if (strongSelf.page > 1) {
            [strongSelf.commentView.commentTableView.indicator stopAnimating];
        }
        NSArray *comments = obj[@"data"][@"comments"];
        if (![comments isKindOfClass:[NSNull class]]) {
            for (NSDictionary *dic in comments) {
                YXCommentModel *commentModel = [YXCommentModel commentModelWithDic:dic];
                [strongSelf.commentView.commentTableView.dataArr addObject:commentModel];
            }
            if (comments.count > 0) {
                [strongSelf.commentView.commentTableView reloadData];
            }
        }
        [self createWildDog];
    } fail:^(NSError *error, NSString *errorMessage) {
        YXLiveDetailViewController *strongSelf = weakSelf;
        [strongSelf createWildDog];
        if (strongSelf.page > 1) {
            strongSelf.page -= 1;
            [strongSelf.commentView.commentTableView.indicator stopAnimating];
        }
    }];
    
}


- (UIView *)createRePlayViewBottomCover {
    UIView *rePlayViewBottomCover = [[UIView alloc] init];
    rePlayViewBottomCover.backgroundColor = [UIColor colorWithWhite:0 alpha:0.9];
    UISlider *slider = [[UISlider alloc] init];
    [rePlayViewBottomCover addSubview:slider];
    slider.tintColor = [UIColor redColor];
    UIImage * thumbImage = [UIImage yx_circleImageWithFillColor:[UIColor whiteColor] strokeColor:[UIColor redColor] radius:6];
    [slider setThumbImage:thumbImage forState:UIControlStateNormal];
    [slider addTarget:self action:@selector(timeChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(timeChangedFinish:) forControlEvents:UIControlEventTouchUpInside];
    self.slider = slider;
    
    YXCalculateTimeLabel *timeLab = [[YXCalculateTimeLabel alloc] init];
    timeLab.totalTime = 0;
    timeLab.currentTime = 0;
    [rePlayViewBottomCover addSubview:timeLab];
    self.timeLab = timeLab;
    
    UIButton *controlScreeBtn = [[UIButton alloc] init];
    [controlScreeBtn setImage:[UIImage imageNamed:@"detail_fullscreen_btn_normal"] forState:UIControlStateNormal];
    [controlScreeBtn addTarget:self action:@selector(didClickControllScreenBtn) forControlEvents:UIControlEventTouchUpInside];
    [rePlayViewBottomCover addSubview:controlScreeBtn];
    self.controlScreeBtn = controlScreeBtn;
    
    
    [controlScreeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.right.bottom.equalTo(rePlayViewBottomCover);
        make.width.equalTo(@33);
    }];
    [slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(rePlayViewBottomCover).offset(6);
        make.left.equalTo(rePlayViewBottomCover).offset(10);
        make.right.equalTo(controlScreeBtn.mas_left).offset(-10);
        make.height.equalTo(@10);
    }];
    [timeLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(slider.mas_bottom).offset(2);
        make.left.equalTo(slider);
        make.height.equalTo(@14);
        make.width.equalTo(@120);
    }];
    return rePlayViewBottomCover;
}

- (void)createWildDog {
    if (self.wilddogRef || !self.liveStream) {
        return ;
    }
    NSString *wildDogUrl = [NSString stringWithFormat:@"%@%@/comments",YXWildDogLivestream,self.liveStream.ID];
    NSLog(@"\n wildDogUrl: %@",wildDogUrl);
    
    self.wilddogRef = [[Wilddog alloc] initWithUrl:wildDogUrl];
    __weak typeof(self) weakSelf = self;
    self.wilddogHandle = [self.wilddogRef observeEventType:WEventTypeChildAdded withBlock:^(WDataSnapshot * _Nonnull snapshot) {
        YXLiveDetailViewController *strongSelf = weakSelf;
        
        NSData *data = [snapshot.value dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        YXCommentModel *commentModel = [YXCommentModel commentModelWithDic:dic];
        if (strongSelf.commentView.commentTableView.dataArr.count > 0) {
            YXCommentModel *firstComment = (YXCommentModel *)strongSelf.commentView.commentTableView.dataArr.firstObject;
            if (commentModel.floor.integerValue > firstComment.floor.integerValue) {
                [strongSelf.commentView.commentTableView.dataArr insertObject:commentModel atIndex:0];
                [strongSelf.commentView.commentTableView  insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]  withRowAnimation:UITableViewRowAnimationNone];
            }
        } else {
            [strongSelf.commentView.commentTableView.dataArr insertObject:commentModel atIndex:0];
            [strongSelf.commentView.commentTableView  insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]  withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
    self.wilddogRemoveHandle = [self.wilddogRef observeEventType:WEventTypeChildRemoved withBlock:^(WDataSnapshot * _Nonnull snapshot) {
        //        YXLiveDetailViewController *strongSelf = weakSelf;
        NSLog(@"\n 删除：%@",snapshot.value);
    }];
}

- (void)createCalculateTimer {
    __weak typeof(self) weakSelf = self;
    self.calculateTimer = [NSTimer yx_ScheduledTimerWithTimeInterval:1 block:^{
        YXLiveDetailViewController *strongSelf = weakSelf;
        if (strongSelf.playView.currentTime.timescale != 0) {
            strongSelf.slider.value = strongSelf.playView.currentTime.value / strongSelf.playView.currentTime.timescale;
        }
        strongSelf.timeLab.currentTime = strongSelf.slider.value;
    } repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.calculateTimer forMode:NSRunLoopCommonModes];
}

- (void)dealCalculateTimer {
    [self.calculateTimer invalidate];
    self.calculateTimer = nil;
}

- (void)createNoRepeatTimer {
    //创建新的之前，取消之前的
    [self dealNoRepeatTimer];
    __weak typeof(self) weakSelf = self;
    self.noRepeatTimer = [NSTimer yx_ScheduledTimerWithTimeInterval:3 block:^{
        YXLiveDetailViewController *strongSelf = weakSelf;
        [UIView animateWithDuration:0.4 animations:^{
            strongSelf.playBtn.alpha = 0;
            strongSelf.rePlayViewBottomCover.alpha = 0;
        } completion:^(BOOL finished) {
            strongSelf.playBtn.hidden = YES;
            strongSelf.rePlayViewBottomCover.hidden = YES;
            strongSelf.playBtn.alpha = 1;
            strongSelf.rePlayViewBottomCover.alpha = 1;
        }];
        
    } repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.noRepeatTimer forMode:NSRunLoopCommonModes];
}

- (void)dealNoRepeatTimer {
    [self.noRepeatTimer invalidate];
    self.noRepeatTimer = nil;
    
}

#pragma mark target
- (void)didTapPlayView {
    [self.commentView resignTextviewFirstResponder];
    self.playBtn.hidden = !self.playBtn.hidden;
    self.rePlayViewBottomCover.hidden = !self.rePlayViewBottomCover.hidden;
    if (!self.playBtn.hidden) {
        [self createNoRepeatTimer];
    } else {
        [self dealNoRepeatTimer];
    }
}

- (void)didClickPlayBtn:(UIButton *)sender {
    self.playView.play = !self.playView.play;
}

- (void)didClickControllScreenBtn {
    UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
    switch (interfaceOrientation) {
            //竖屏转横屏
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeRight) forKey:@"orientation"];
            break;
            //横屏转竖屏
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait) forKey:@"orientation"];
            break;
        default:
            break;
    }
}

- (void)timeChanged:(UISlider *)sender {
    [self dealNoRepeatTimer];
    if (self.liveStream.status == 2) {
        if (self.calculateTimer) {
            [self dealCalculateTimer];
        }
        self.timeLab.currentTime = sender.value;
    }
}

- (void)timeChangedFinish:(UISlider *)sender {
    [self createNoRepeatTimer];
    if (self.liveStream.status == 2) {
        CMTime time = CMTimeMake(sender.value, 1);
        [self.playView seekTo:time];
        if (!self.calculateTimer) {
            [self createCalculateTimer];
        }
    } else {
        sender.value = 0;
    }
}

- (void) setStatusBarHidden:(BOOL)isHidden {
    self.isStatusBarHidden = isHidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection
              withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super willTransitionToTraitCollection:newCollection
                 withTransitionCoordinator:coordinator];
    [self.commentView resignTextviewFirstResponder];
    [coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext> context) {
        if (newCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact) {
            [self.playView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.edges.equalTo(self.view);
            }];
            self.titleBar.hidden = YES;
            self.fd_interactivePopDisabled = YES;
        } else {
            [self.playView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.left.right.equalTo(self.view);
                make.height.equalTo(self.playView.mas_width).multipliedBy(0.56);
            }];
            self.titleBar.hidden = NO;
            self.fd_interactivePopDisabled = NO;
        }
    } completion:nil];
}

- (void) showMessage:(NSString *)message {
    UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    lab.layer.cornerRadius = 5;
    lab.layer.masksToBounds = YES;
    lab.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
    lab.text = message;
    lab.textAlignment = NSTextAlignmentCenter;
    lab.textColor = [UIColor whiteColor];
    lab.numberOfLines = 0;
    lab.center = [UIApplication sharedApplication].keyWindow.center;
    [[UIApplication sharedApplication].keyWindow addSubview:lab];
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_main_queue(), ^{
        [lab removeFromSuperview];
    });
}

- (BOOL)prefersStatusBarHidden {
    return self.isStatusBarHidden;
}

- (void)dealloc
{
    if (self.wilddogRef) {
        [self.wilddogRef removeObserverWithHandle:self.wilddogHandle];
        [self.wilddogRef removeObserverWithHandle:self.wilddogRemoveHandle];
        self.wilddogRef = nil;
    }
    [self dealCalculateTimer];
    [self dealNoRepeatTimer];
    NSLog(@"\n YXLiveDetailViewController 销毁");
}


@end

//
//  ViewController.m
//  WebViewPerformance
//
//  Created by henry on 2020/12/22.
//  Copyright (c) 2021 Tencent. All rights reserved.


#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JSContext.h>
/*
 ViewController
 */
@interface ViewController ()<WKNavigationDelegate, WKUIDelegate>

/// 网页视图
@property (strong, nonatomic) WKWebView *wk_WebView;

@end

/*
 ViewController
 */
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self createwk_WebView];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(100, 300, 100, 100)];
    btn.center = self.view.center;
    [btn setTitle:@"获取Timing" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(haha) forControlEvents:UIControlEventTouchUpInside];
    btn.backgroundColor = [UIColor redColor];
    [self.view addSubview:btn];
    
}

- (void)createwk_WebView {
    if (!_wk_WebView) {
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc]init];
        config.preferences = [[WKPreferences alloc]init];
        config.userContentController = [[WKUserContentController alloc]init];
                
        NSString *jspath = [[NSBundle mainBundle]pathForResource:@"jscode.txt" ofType:nil];
           NSString *str = [NSString stringWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
           //注入时机是在webview加载状态WKUserScriptInjectionTimeAtDocumentStart、WKUserScriptInjectionTimeAtDocumentEnd
        WKUserScript *userScript = [[WKUserScript alloc] initWithSource:str
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                       forMainFrameOnly:YES];
        //关键代码，把jscode.txt读取的内容字符注入到js
        [config.userContentController addUserScript:userScript];
        [config.userContentController addScriptMessageHandler:self name:@"timing"];

        _wk_WebView = [[WKWebView alloc]initWithFrame:self.view.bounds configuration:config];
        _wk_WebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _wk_WebView.navigationDelegate = self;
        _wk_WebView.UIDelegate = self;

        NSURL *url = [NSURL URLWithString:@"https://isee.weishi.qq.com/ws/wact/challenge_races_tab/index.html"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        [_wk_WebView loadRequest:request];
        [self.view addSubview:self.wk_WebView];
    }
}

-(void)haha{
    // 此处是设置需要调用的js方法以及将对应的参数传入，需要以字符串的形式
    
    id result = [self evaluateJavaScript:self.wk_WebView jsFounction:@"timing()"];

    
}


-(id)evaluateJavaScript:(WKWebView *)webView
            jsFounction:(NSString *)jsFounction{
    __block BOOL end = NO;

    __block id result;
    [webView evaluateJavaScript:jsFounction
              completionHandler:^(id obj, NSError * _Nullable error) {
        result = obj;
        end = YES;
    }];
    while (!end) {
           [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    return result;
}

@end

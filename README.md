![](https://images.xiaozhuanlan.com/photo/2021/044c9cff7d3bbcfe88439e8acc35f825.png)
## 背景：

H5在如今的App内占得比重越来越多，2020、2021年微视春节活动中，微视客户端有大量的H5页面，性能测试主要关注三个指标

- 白屏时间

- 首屏时间

- 加载成功率

2020年的春节活动采用手工测试，主要采用录屏分帧的手法+人工统计的方法来测试。痛点主要有：

（1）测试步骤非常繁琐

（2）对于白屏、首屏的结束时间点不同的测试人员会有不同判断，对测试结果造成一定的偏差

（3）无法反映是哪个阶段耗时较长，开发同学没有办法进行针对性的优化。参考[移动端H5测试方案-----腾讯视频测试组]()抓包的方案，很难实现自动化，切配置较为繁琐，对不熟悉网络协议和抓包的同学来说使用成本较高。

经过调研，总结本方案，具有以下特点

（1）不需要业务开发的同学配合
（2）跨iOS、Android双端
（3）测试结果精准
（4）容易实现自动化和大规模批量测试

## 一、原理
![](https://images.xiaozhuanlan.com/photo/2021/f13310355ef06c3f270b741e764b220f.png)
1、前端的同学应该都比较熟悉window.performance.timing这个接口，这个接口能获取到前端页面加载的各个事件的时间戳，并且市面上绝大多数浏览器内核都支持该接口协议
![](https://images.xiaozhuanlan.com/photo/2021/f40e21ec29570662849963139a3932a1.png)
2、客户端可以通过webview注入js代码

3、客户端可以调用web中的js代码

基于以上事实，让我们在客户端获取web性能成为可能。

## 二、实现（仅以iOS中的WKWebview为例）

1、拷贝以下内容到txt文件，然后将文件拷贝进bundle

```
function timing() {
    
    let timing = window.performance.timing
    var result ={
                  // 后端响应时间
                  response: String(timing.responseStart - timing.requestStart),
                  // html页面下载时间
                  firstpaint: String(timing.responseEnd - timing.responseStart),
                  // domready
                  domready: String(timing.domContentLoadedEventStart - timing.responseEnd),
                  // 准备新页面所耗费的时间
                  readystart: String(timing.fetchStart - timing.navigationStart),
                  // 重定向期花费的时间
                  redirecttime: String(timing.fetchStart - timing.navigationStart),
                  // 应用程序缓存
                  appcachetime: String(timing.domainLookupStart - timing.fetchStart),
                  // DNS查询时间
                  dns: String(timing.domainLookupEnd - timing.domainLookupStart),
                  // TCP连接时间
                  tcp: String(timing.connectEnd - timing.connectStart),
                  // 请求期间花费的时间
                  requesttime:String(timing.responseEnd - timing.requestStart),
                  // 请求完成dom加载
                  initdomtreetime:String(timing.domInteractive - timing.responseEnd),
                  // 加载活动时间
                  loadeventTime: String(timing.loadEventEnd - timing.loadEventStart),
                  // 首屏时间（截止20201229，微视60%的web页面都能获取到这个值，有的存量页面没有，其他产品没有）
                  firstscreentime: window.localStorage.fmpTime,
                  // 白屏时间
                  whitescreentime: String(timing.domLoading - timing.fetchStart),
                  // 解析dom树耗时
                  analyzdomtime: String(timing.domInteractive - timing.domLoading),
    }

    // return JSON.stringify(window.performance.timing)
    return result
    
}
```

> 值得注意的是：firstscreentime（首屏时间）也就是我们常说的fmp（first meaning paint）计算方法可以参考https://juejin.cn/post/6844903929717915661， 但是业务和业务差别较大，很难使用统一的算法计算fmp时间，因为我们很难规定到底什么样的元素才是页面的主要元素（有的是图片，有的是视频，有的是文字）。所以微视的解决方案是让前端的同时将fmp的时间存储到window.localStorage.fmpTime内，然后在执行timing的函数的时候，主动去取这个信息。

2、在webView的config中注入js代码

```javascript
 WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc]init];
 config.preferences = [[WKPreferences alloc]init];
 config.userContentController = [[WKUserContentController alloc]init];
 NSString *jspath = [[NSBundle mainBundle]pathForResource:@"jscode.txt" ofType:**nil**];
 NSString *str = [NSString stringWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:**nil**];
 //注入时机是在webview加载状态WKUserScriptInjectionTimeAtDocumentStart、WKUserScriptInjectionTimeAtDocumentEnd
 WKUserScript *userScript = [[WKUserScript alloc] initWithSource:str injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:**YES**];
 //关键代码，把jscode.txt读取的内容字符注入到js
 [config.userContentController addUserScript:userScript];
 [config.userContentController addScriptMessageHandler:**self** name:@"timing"];
 _wk_WebView = [[WKWebView alloc]initWithFrame:**self**.view.bounds configuration:config];
```



3、执行js方法

```javascript
-(NSDictionary *)result{
    __block BOOL end = NO;
    __block id result;
    [self.webview evaluateJavaScript:@"timing()" completionHandler:^(id obj, NSError * _Nullable error) {
        result = obj;
        end = YES;
    }];
    while (!end) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    }
    return result;
}
```

> 1、WKWebview中的evaluateJavaScript方法只能在主线程中调用，且只能异步执行，上面的方法可同步返回js的返回值结果。
>
> 2、UIWebView是同步返回的



Demo
iOS：https://github.com/BBC6BAE9/NativeWebViewPerformance-iOS
Android：原理是一样的，晚一点传一个demo

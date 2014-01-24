//
//  AppDelegate.m
//  CompleteUnlessOpen
//
//  Copyright (c) 2013, 2014 Rob Napier.
//
//  Demonstrates changing file protections on a logfile so that it is as protected as it
//  can be when the device is locked or unlocked.

/*
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 DEALINGS IN THE SOFTWARE.
 */

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, readwrite, strong) dispatch_block_t loggerBlock;
@property (nonatomic, readwrite, assign) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic, readwrite, copy) NSString *logPath;
@end

@implementation AppDelegate

- (void)setLogFileProtection:(NSString *)protection
{
  NSError *error;
  if (! [[NSFileManager defaultManager] setAttributes:@{NSFileProtectionKey : protection}
                                         ofItemAtPath:self.logPath
                                                error:&error]) {
    NSLog(@"Could not set file protection: %@", error);
  }
}

- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
  NSLog(@"%s", __PRETTY_FUNCTION__);

  [self setLogFileProtection:NSFileProtectionCompleteUnlessOpen];
}

- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application {
  NSLog(@"%s", __PRETTY_FUNCTION__);

  [self setLogFileProtection:NSFileProtectionCompleteUnlessOpen];
}

- (void)startLogger
{
  self.logPath = [DocumentsDirectory() stringByAppendingPathComponent:@"log.txt"];
  NSOutputStream *logStream = [NSOutputStream outputStreamToFileAtPath:self.logPath append:YES];
  [logStream open];

  [self setLogFileProtection:NSFileProtectionComplete];

  __weak typeof(self) weakSelf = self;
  dispatch_block_t loggerBlock = ^{
    NSString *logEntry = [[[NSDate date] description] stringByAppendingString:@"\n"];
    if ([logStream write:(const uint8_t *)[logEntry UTF8String]
               maxLength:[logEntry lengthOfBytesUsingEncoding:NSUTF8StringEncoding]] == -1)
    {
      NSLog(@"Could not write to logfile: %@", [logStream streamError]);
    }
    else
    {
      NSLog(@"Logged");
    }

    dispatch_block_t loopBlock = weakSelf.loggerBlock;
    if (loopBlock) {
      double delayInSeconds = 2.0;
      dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
      dispatch_after(popTime, dispatch_get_main_queue(), loopBlock);
    }
    else {
      NSLog(@"Logger stopped");
    }
  };

  self.loggerBlock = loggerBlock;

  dispatch_async(dispatch_get_main_queue(), loggerBlock);
}

- (void)stopLogger
{
  self.loggerBlock = nil;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  [self startLogger];

  NSLog(@"Lock device now");
  // Override point for customization after application launch.
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  NSLog(@"%s", __PRETTY_FUNCTION__);
  // Keep running until the OS kills us.
  self.backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
    NSLog(@"Failed to finish before we were killed.");
    [application endBackgroundTask:self.backgroundTask];
    self.backgroundTask = UIBackgroundTaskInvalid;
  }];

}

NSString *DocumentsDirectory() {
  return NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
}

@end

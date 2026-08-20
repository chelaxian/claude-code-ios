//
//  ClaudeCode.app launcher
//
//  iGhostty 0.2.5 provides the narrow public URL handoff `ighostty://claude`.
//  It contains no command or arguments. The trusted iGhostty app owns the
//  authenticated XPC connection to its root daemon and opens only the fixed
//  Claude shell wrapper supplied by this package.
//
//  This is intentionally not a generic command URL: accepting command text
//  here would turn a home-screen launcher into command injection against a
//  privileged terminal daemon.
//

#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

static NSString *const kIghosttyClaudeURL = @"ighostty://claude";
static NSString *const kIghosttyBundleID = @"wiki.qaq.iGhostty";

// Candidate uiopen locations: rootless jailbreaks put it under /var/jb.
static NSString *const kUIOpenPaths[] = {
    @"/var/jb/usr/bin/uiopen",
    @"/usr/bin/uiopen",
};
static const int kUIOpenPathCount = (int)(sizeof(kUIOpenPaths) / sizeof(kUIOpenPaths[0]));

// The first call starts iGhostty on a cold device; the second is routed to the
// already-running scene. iGhostty also handles the URL in connectionOptions,
// but retrying makes SpringBoard handoff failures visible instead of silent.
static const NSTimeInterval kWarmupDelay = 0.8;
static const NSTimeInterval kRetryDelays[] = { 1.0, 2.0 };
static const int kRetryCount = (int)(sizeof(kRetryDelays) / sizeof(kRetryDelays[0]));

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UILabel *statusLabel;
@end

@implementation AppDelegate

- (void)setStatus:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = text;
    });
}

static NSString *FindUIOpen(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (int i = 0; i < kUIOpenPathCount; i++) {
        if ([fm isExecutableFileAtPath:kUIOpenPaths[i]]) {
            return kUIOpenPaths[i];
        }
    }
    return nil;
}

static BOOL RunUIOpen(NSString *flag, NSString *value) {
    NSString *tool = FindUIOpen();
    if (tool == nil) {
        return NO;
    }

    char *argv[] = {
        (char *)tool.UTF8String,
        (char *)flag.UTF8String,
        (char *)value.UTF8String,
        NULL,
    };

    pid_t pid = 0;
    if (posix_spawn(&pid, argv[0], NULL, NULL, argv, environ) != 0) {
        return NO;
    }

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        return NO;
    }
    return WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

- (void)openClaudeInIghosttyAttempt:(int)attempt {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL ok = RunUIOpen(@"--url", kIghosttyClaudeURL);
        if (ok) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                exit(0);
            });
            return;
        }

        if (attempt < kRetryCount) {
            [self setStatus:@"Waiting for iGhostty…"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(kRetryDelays[attempt] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self openClaudeInIghosttyAttempt:attempt + 1];
            });
            return;
        }

        [self setStatus:@"Could not open iGhostty.\n\n"
                         "Install iGhostty 0.2.5 or later,\n"
                         "then reinstall Claude Code."];
    });
}

- (void)launchIghosttyThen:(void (^)(void))next {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL launched = RunUIOpen(@"--bundleid", kIghosttyBundleID);
        if (launched) {
            [self setStatus:@"Opening iGhostty…"];
        }
        NSTimeInterval delay = launched ? kWarmupDelay : 0.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (next) next();
        });
    });
}

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.56 blue:0.2 alpha:1.0];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Starting Claude Code…";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightMedium];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [vc.view addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:24.0],
        [label.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-24.0],
    ]];
    self.statusLabel = label;

    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    [self launchIghosttyThen:^{
        [self openClaudeInIghosttyAttempt:0];
    }];

    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

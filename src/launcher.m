//
//  ClaudeCode.app launcher
//
//  The original CyPwn launcher opened "newterm3://run?command=..." — a scheme
//  that NO app on the device registers (NewTerm 3 declares only "ssh"), so
//  -openURL: failed and the completion handler called exit(0). The app looked
//  like it crashed instantly on launch.
//
//  This launcher instead drives NewTerm through the scheme it really declares:
//
//      ssh://<alias>   ->  NewTerm builds "ssh <alias>" and types it into the
//                          terminal, followed by Return.
//
//  The <alias> is a Host entry in ~/.ssh/config that points at the device's own
//  sshd, whose authorized_keys carries a forced command running the claude
//  wrapper. Net effect: tapping the icon opens a terminal already running
//  Claude Code.
//
//  Cold-start caveat (measured on iOS 17 / NewTerm 3.0~beta1):
//  NewTerm handles incoming URLs only in -scene:openURLContexts:, which UIKit
//  calls for an ALREADY RUNNING scene. On a cold launch the URL arrives in
//  connectionOptions of -scene:willConnectToSession:options:, which NewTerm
//  ignores — the terminal opens but the command never runs. So we do it in two
//  steps: first wake NewTerm by bundle id, then, once it is up, send the ssh://
//  URL to the now-warm scene.
//
//  Both steps go through `uiopen` rather than -openURL:. After step 1 NewTerm
//  is frontmost and we are backgrounded, and a backgrounded app's -openURL: is
//  not reliably honoured; uiopen talks to SpringBoard directly and does not
//  care what state we are in.
//

#import <UIKit/UIKit.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

// Scheme target. Must match the Host alias in ~/.ssh/config.
static NSString *const kClaudeSSHURL = @"ssh://claude";

// NewTerm 3 bundle identifier.
static NSString *const kNewTermBundleID = @"ws.hbang.Terminal";

// Candidate uiopen locations: rootless jailbreaks put it under /var/jb.
static NSString *const kUIOpenPaths[] = {
    @"/var/jb/usr/bin/uiopen",
    @"/usr/bin/uiopen",
};
static const int kUIOpenPathCount = (int)(sizeof(kUIOpenPaths) / sizeof(kUIOpenPaths[0]));

// How long to let NewTerm come up before sending it the URL. It has to spawn a
// pty and lay out its scene; sending the URL too early lands in the cold-start
// path that drops it.
static const NSTimeInterval kWarmupDelay = 2.0;

// Extra attempts if the first URL does not take, e.g. on a cold, slow launch.
static const NSTimeInterval kRetryDelays[] = { 1.5, 2.5 };
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

// First uiopen that actually exists, or nil.
static NSString *FindUIOpen(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (int i = 0; i < kUIOpenPathCount; i++) {
        if ([fm isExecutableFileAtPath:kUIOpenPaths[i]]) {
            return kUIOpenPaths[i];
        }
    }
    return nil;
}

// Run uiopen with the given argument pair, returning YES on exit status 0.
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

// Send the ssh:// URL, retrying a couple of times if NewTerm was not ready.
- (void)sendClaudeURLWithAttempt:(int)attempt {
    // uiopen blocks on SpringBoard, so keep it off the main thread.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL ok = RunUIOpen(@"--url", kClaudeSSHURL);

        if (ok) {
            // NewTerm is frontmost and running the command; nothing left to do.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                exit(0);
            });
            return;
        }

        if (attempt < kRetryCount) {
            [self setStatus:@"Waiting for NewTerm…"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(kRetryDelays[attempt] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self sendClaudeURLWithAttempt:attempt + 1];
            });
            return;
        }

        // Stay on screen with a diagnostic instead of vanishing — a silent
        // exit(0) here is exactly what made the original build look crashy.
        [self setStatus:@"Could not reach NewTerm.\n\n"
                         "Install NewTerm 3, then check that\n"
                         "~/.ssh/config defines: Host claude"];
    });
}

// Wake NewTerm without an URL, then run `next` after the warm-up delay.
- (void)launchNewTermThen:(void (^)(void))next {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        BOOL launched = RunUIOpen(@"--bundleid", kNewTermBundleID);

        // If the wake failed we still try the URL: on a warm NewTerm it works
        // on its own, and on a cold one the first URL at least brings the app
        // up so a retry can land.
        NSTimeInterval delay = launched ? kWarmupDelay : 0.0;
        if (launched) {
            [self setStatus:@"Opening terminal…"];
        }

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

    // Step 1 wakes NewTerm; step 2 hands it the command once a scene exists.
    [self launchNewTermThen:^{
        [self sendClaudeURLWithAttempt:0];
    }];

    return YES;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

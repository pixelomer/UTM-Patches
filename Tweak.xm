#import <UIKit/UIKit.h>
#import <MetalKit/MetalKit.h>

@interface __ConfigObject : NSObject
- (NSString *)systemArchitecture;
@end

@interface UTMQemuSystem : NSObject
- (__ConfigObject *)configuration;
@end

%hook UTMQemuSystem

- (void)pushArgv:(NSString *)arg {
	if (
        ![self.configuration.systemArchitecture isEqualToString:@"i386"] &&
        ![self.configuration.systemArchitecture isEqualToString:@"x86_64"] &&
        [arg isEqualToString:@"qxl"]
    ) arg = @"std";
	%orig;
}

%end

typedef NS_ENUM(NSUInteger, SendButtonType) {
    SEND_BUTTON_NONE = 0,
    SEND_BUTTON_LEFT = 1,
    SEND_BUTTON_MIDDLE = 2,
    SEND_BUTTON_RIGHT = 4
};

@interface CSInput : NSObject
- (void)sendMouseButton:(SendButtonType)button pressed:(BOOL)pressed point:(CGPoint)point;
@end

@interface VMCursor : NSObject
- (void)setCenter:(CGPoint)center;
@end

@interface VMDisplayMetalViewController : UIViewController {
	VMCursor *_cursor;
}
@property (weak, nonatomic) MTKView *mtkView;
@property (nonatomic, weak) CSInput *vmInput;
@property (strong, nonatomic) UISelectionFeedbackGenerator *clickFeedbackGenerator;
@property (nonatomic, readonly) BOOL touchscreen;
- (void)PXHandleTap:(SendButtonType)type sender:(UITapGestureRecognizer *)sender;
@end

@interface MTKView(UTMPPCFix)
@property (nonatomic, assign) BOOL isVMScreen;
@property (nonatomic, assign) NSTimeInterval touchesBeginTime;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
- (VMDisplayMetalViewController *)_viewControllerForAncestor;
@end

%hook UTMRenderer

- (UTMRenderer *)initWithMetalKitView:(MTKView *)view {
	view.isVMScreen = YES;
    view.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc]
        initWithTarget:view
        action:@selector(PXHandleLongPress:)
    ];
    view.longPressGestureRecognizer.minimumPressDuration = 0.5;
    [view addGestureRecognizer:view.longPressGestureRecognizer];
	return %orig;
}

%end

%hook MTKView
%property (nonatomic, assign) BOOL isVMScreen;
%property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
%property (nonatomic, assign) NSTimeInterval touchesBeginTime;

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
	%orig;
    if (self.isVMScreen) {
        self.touchesBeginTime = [NSDate date].timeIntervalSince1970;
    }
}

%new
- (void)PXHandleLongPress:(UILongPressGestureRecognizer *)sender {
    VMDisplayMetalViewController *vc = self._viewControllerForAncestor;
    if (sender.state == UIGestureRecognizerStateBegan) {
        [vc.clickFeedbackGenerator selectionChanged];
        [vc.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:YES point:CGPointZero];
    }
    else if (sender.state == UIGestureRecognizerStateEnded) {
        [vc.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:NO point:CGPointZero];
    }
}

%end

%hook VMDisplayMetalViewController

%new
- (void)PXHandleTap:(NSUInteger)type sender:(UITapGestureRecognizer *)sender {
    NSTimeInterval timePast = [NSDate date].timeIntervalSince1970 - self.mtkView.touchesBeginTime;
    if ((sender.state == UIGestureRecognizerStateEnded) && (timePast <= 0.2)) {
        if (self.touchscreen) {
            MSHookIvar<VMCursor *>(self, "_cursor").center = [sender locationInView:sender.view];
        }
        [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:YES point:CGPointZero];
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC*0.1),
            dispatch_get_main_queue(),
            ^{
                [self.vmInput sendMouseButton:SEND_BUTTON_LEFT pressed:NO point:CGPointZero];
            }
        );
        [self.clickFeedbackGenerator selectionChanged];
    }
}

- (void)gestureTap:(UITapGestureRecognizer *)sender {
    [self PXHandleTap:SEND_BUTTON_LEFT sender:sender];
}

- (void)gestureTwoTap:(UITapGestureRecognizer *)sender {
    [self PXHandleTap:SEND_BUTTON_RIGHT sender:sender];
}

%end
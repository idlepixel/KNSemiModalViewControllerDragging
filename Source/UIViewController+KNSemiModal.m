//
//  KNSemiModalViewController.m
//  KNSemiModalViewController
//
//  Created by Kent Nguyen on 2/5/12.
//  Copyright (c) 2012 Kent Nguyen. All rights reserved.
//

#import "UIViewController+KNSemiModal.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

const struct KNSemiModalOptionKeys KNSemiModalOptionKeys = {
	.traverseParentHierarchy = @"KNSemiModalOptionTraverseParentHierarchy",
	.pushParentBack          = @"KNSemiModalOptionPushParentBack",
	.animationDuration       = @"KNSemiModalOptionAnimationDuration",
	.animationOutDuration    = @"KNSemiModalOptionAnimationOutDuration",
	.animationAngle          = @"KNSemiModalOptionAnimationAngle",
	.parentAlpha             = @"KNSemiModalOptionParentAlpha",
    .parentScaleInitial      = @"KNSemiModalOptionParentScaleInitial",
    .parentScaleFinal        = @"KNSemiModalOptionParentScaleFinal",
    .parentDisplacement      = @"KNSemiModalOptionParentDisplacement",
	.shadowOpacity           = @"KNSemiModalOptionShadowOpacity",
	.transitionInStyle       = @"KNSemiModalTransitionInStyle",
	.transitionOutStyle      = @"KNSemiModalTransitionOutStyle",
	.transitionInDirection   = @"KNSemiModalTransitionInDirection",
	.transitionOutDirection  = @"KNSemiModalTransitionOutDirection",
	.modalPosition           = @"KNSemiModalModalPosition",
    .disableCancel           = @"KNSemiModalOptionDisableCancel",
    .backgroundColor         = @"KNSemiModalOptionBackgroundColor",
    .useParentWidth          = @"KNSemiModalOptionUseParentWidth",
    .statusBarHeight         = @"KNSemiModalOptionStatusBarHeight",
    .customWidth             = @"KNSemiModalOptionCustomWidth",
    .customHeight            = @"KNSemiModalOptionCustomHeight",
};

#define kSemiModalViewController           @"PaPQC93kjgzUanz"
#define kSemiModalDismissBlock             @"l27h7RU2dzVfPoQ"
#define kSemiModalPresentingViewController @"QKWuTQjUkWaO1Xr"
#define kSemiModalModalContainerView       @"1XrQTUkWQjKaOWu"
#define kSemiModalOverlayTag               10001
#define kSemiModalScreenshotTag            10002
#define kSemiModalModalViewTag             10003
#define kSemiModalModalBackingViewTag      10004
#define kSemiModalDismissButtonTag         10005
#define kSemiModalOverlayBackgroundTag     10006

@interface NSObject (YMOptionsAndDefaults)

- (void)ym_registerOptions:(NSDictionary *)options defaults:(NSDictionary *)defaults;
- (id)ym_optionOrDefaultForKey:(NSString*)optionKey;

@end

@interface NSObject (KNSemiModalInternal)

-(NSDictionary *)kn_semiModelDefaultsDictionary;

@end

// a simple subclass to hold the model sub-views

@interface KNSemiModalContainerView : UIView
@end

@implementation KNSemiModalContainerView
@end

@interface UIViewController (KNSemiModalInternal)

-(UIView*)kn_parentTarget;
-(KNSemiModalContainerView *)kn_containerViewForTarget:(UIView *)target;
-(CAAnimationGroup*)animationGroupForward:(BOOL)_forward;

@end

@implementation NSObject (KNSemiModalInternal)

-(NSDictionary *)kn_semiModelDefaultsDictionary
{
    double animationAngle = 15.0f;
    double parentDisplacement = 0.08f;
    BOOL useParentWidth = YES;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
        // The rotation angle is minor as the view is nearer
        animationAngle = 7.5f;
        parentDisplacement = 0.04f;
        useParentWidth = NO;
    }
    return @{
             KNSemiModalOptionKeys.traverseParentHierarchy : @(YES),
             KNSemiModalOptionKeys.pushParentBack : @(YES),
             KNSemiModalOptionKeys.animationDuration : @(0.5),
             KNSemiModalOptionKeys.animationAngle : @(animationAngle),
             KNSemiModalOptionKeys.parentAlpha : @(0.5),
             KNSemiModalOptionKeys.parentScaleInitial : @(0.95),
             KNSemiModalOptionKeys.parentScaleFinal : @(0.8),
             KNSemiModalOptionKeys.parentDisplacement : @(parentDisplacement),
             KNSemiModalOptionKeys.shadowOpacity : @(0.8),
             KNSemiModalOptionKeys.transitionInStyle : @(KNSemiModalTransitionStyleSlide),
             KNSemiModalOptionKeys.transitionOutStyle : @(KNSemiModalTransitionStyleSlide),
             KNSemiModalOptionKeys.transitionInDirection : @(KNSemiModalTransitionDirectionAutomatic),
             KNSemiModalOptionKeys.transitionOutDirection : @(KNSemiModalTransitionDirectionAutomatic),
             KNSemiModalOptionKeys.modalPosition : @(KNSemiModalModalPositionBottom),
             KNSemiModalOptionKeys.disableCancel : @(NO),
             KNSemiModalOptionKeys.backgroundColor : [UIColor blackColor],
             KNSemiModalOptionKeys.useParentWidth : @(useParentWidth),
             KNSemiModalOptionKeys.statusBarHeight : @(20.0f),
             KNSemiModalOptionKeys.customWidth : @(-1.0f),
             KNSemiModalOptionKeys.customHeight : @(-1.0f),
             };
}

@end

@implementation UIViewController (KNSemiModalInternal)

-(UIViewController*)kn_parentTargetViewController {
	UIViewController * target = self;
	if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.traverseParentHierarchy] boolValue]) {
        // cover UINav & UITabbar as well
		while (target.parentViewController != nil) {
			target = target.parentViewController;
		}
    }
	return target;
}
-(UIView*)kn_parentTarget
{
    return [self kn_parentTargetViewController].view;
}

#pragma mark Options and defaults

-(void)kn_registerDefaultsAndOptions:(NSDictionary*)options
{
	[self ym_registerOptions:options defaults:[self kn_semiModelDefaultsDictionary]];
}

#pragma mark Push-back animation group

-(CAAnimationGroup*)animationGroupForward:(BOOL)_forward {
    
    double animationAngle = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationAngle] doubleValue];
    double parentScaleInitial = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentScaleInitial] doubleValue];
    double parentScaleFinal = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentScaleFinal] doubleValue];
    double parentDisplacement = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentDisplacement] doubleValue];
    
    NSUInteger modalPosition = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.modalPosition] unsignedIntegerValue];
    
    double parentTranslate = [self kn_parentTarget].frame.size.height*parentDisplacement;
    animationAngle = -animationAngle*M_PI/180.0f;
    if (modalPosition == KNSemiModalModalPositionBottom) {
        parentTranslate *= -1.0f;
        animationAngle *= -1.0f;
    }
    
    // Create animation keys, forwards and backwards
    CATransform3D t1 = CATransform3DIdentity;
    t1.m34 = 1.0/-900;
    t1 = CATransform3DScale(t1, parentScaleInitial, parentScaleInitial, 1);
    
    t1 = CATransform3DRotate(t1, animationAngle, 1, 0, 0);
    
    CATransform3D t2 = CATransform3DIdentity;
    t2.m34 = t1.m34;
    
    t2 = CATransform3DTranslate(t2, 0, parentTranslate, 0);
    t2 = CATransform3DScale(t2, parentScaleFinal, parentScaleFinal, 1);
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation.toValue = [NSValue valueWithCATransform3D:t1];
	CFTimeInterval duration = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
    animation.duration = duration/2;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    
    CABasicAnimation *animation2 = [CABasicAnimation animationWithKeyPath:@"transform"];
    animation2.toValue = [NSValue valueWithCATransform3D:(_forward?t2:CATransform3DIdentity)];
    animation2.beginTime = animation.duration;
    animation2.duration = animation.duration;
    animation2.fillMode = kCAFillModeForwards;
    animation2.removedOnCompletion = NO;
    
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.fillMode = kCAFillModeForwards;
    group.removedOnCompletion = NO;
    [group setDuration:animation.duration*2];
    [group setAnimations:[NSArray arrayWithObjects:animation,animation2, nil]];
    return group;
}

-(void)kn_interfaceOrientationDidChange:(NSNotification*)notification {
    BOOL pushParentBack = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue];
    if (pushParentBack) {
        UIView *overlay = [[self kn_parentTarget] viewWithTag:kSemiModalOverlayTag];
        [self kn_addOrUpdateParentScreenshotInView:overlay];
    }
}

-(UIImageView*)kn_addOrUpdateParentScreenshotInView:(UIView*)screenshotContainer {
	UIView *target = [self kn_parentTarget];
	UIView *semiView = [target viewWithTag:kSemiModalModalViewTag];
	
	screenshotContainer.hidden = YES; // screenshot without the overlay!
	semiView.hidden = YES;
	UIGraphicsBeginImageContextWithOptions(target.bounds.size, YES, [[UIScreen mainScreen] scale]);
    [target.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	screenshotContainer.hidden = NO;
	semiView.hidden = NO;
	
	UIImageView* screenshot = (id) [screenshotContainer viewWithTag:kSemiModalScreenshotTag];
	if (screenshot) {
		screenshot.image = image;
	}
	else {
		screenshot = [[UIImageView alloc] initWithImage:image];
		screenshot.tag = kSemiModalScreenshotTag;
		screenshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[screenshotContainer addSubview:screenshot];
	}
	return screenshot;
}

-(KNSemiModalContainerView *)kn_containerViewForTarget:(UIView *)target
{
    NSArray *subviews = target.subviews;
    if (subviews.count > 0) {
        UIView *subview = nil;
        for (NSInteger i = subviews.count - 1; i >= 0; i--) {
            subview = [subviews objectAtIndex:i];
            if ([subview isKindOfClass:[KNSemiModalContainerView class]]) {
                return (KNSemiModalContainerView *)subview;
            }
        }
    }
    return nil;
}

@end

@implementation UIViewController (KNSemiModal)

-(KNSemiModalModalPosition)kn_modalPosition
{
    return [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.modalPosition] unsignedIntegerValue];
}

-(KNSemiModalTransitionStyle)kn_transitionInStyle
{
    return [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionInStyle] unsignedIntegerValue];
}

-(KNSemiModalTransitionStyle)kn_transitionOutStyle
{
    NSNumber *number = [self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionOutStyle];
    KNSemiModalTransitionStyle style;
    if (number != nil) {
        style = number.unsignedIntegerValue;
    } else {
        style = [self kn_transitionInStyle];
    }
    return style;
}

-(KNSemiModalTransitionDirection)kn_determineTransitionDirectionFromStyle:(KNSemiModalTransitionStyle)style
{
    KNSemiModalTransitionDirection direction = KNSemiModalTransitionDirectionNone;
    if (style == KNSemiModalTransitionStyleFade) {
        direction = KNSemiModalTransitionDirectionNone;
    } else {
        KNSemiModalModalPosition position = [self kn_modalPosition];
        switch (position) {
            case KNSemiModalModalPositionTop:
                direction = KNSemiModalTransitionDirectionFromTop;
                break;
                
            default:
                direction = KNSemiModalTransitionDirectionFromBottom;
                break;
        }
    }
    return direction;
}

-(KNSemiModalTransitionDirection)kn_transitionInDirection
{
    KNSemiModalTransitionDirection direction = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionInDirection] unsignedIntegerValue];
    
    if (direction == KNSemiModalTransitionDirectionAutomatic) {
        direction = [self kn_determineTransitionDirectionFromStyle:[self kn_transitionInStyle]];
    }
    
    return direction;
}

-(KNSemiModalTransitionDirection)kn_transitionOutDirection
{
    NSNumber *number = [self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.transitionOutDirection];
    KNSemiModalTransitionDirection direction;
    if (number != nil) {
        direction = number.unsignedIntegerValue;
    } else {
        direction = [self kn_transitionInDirection];
    }
    if (direction == KNSemiModalTransitionDirectionAutomatic) {
        direction = [self kn_determineTransitionDirectionFromStyle:[self kn_transitionOutStyle]];
    }
    
    return direction;
}

-(NSTimeInterval)kn_animationDuration
{
    return [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationDuration] doubleValue];
}

-(NSTimeInterval)kn_animationInDuration
{
    return [self kn_animationDuration];
}

-(NSTimeInterval)kn_animationOutDuration
{
    NSNumber *outDuration = [self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.animationOutDuration];
    NSTimeInterval duration = 0.0f;
    if (outDuration != nil) {
        duration = outDuration.doubleValue;
    } else {
        duration = [self kn_animationDuration];
    }
    return duration;
}

-(void)presentSemiViewController:(UIViewController*)vc {
	[self presentSemiViewController:vc withOptions:nil completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController*)vc
					 withOptions:(NSDictionary*)options {
    [self presentSemiViewController:vc withOptions:options completion:nil dismissBlock:nil];
}
-(void)presentSemiViewController:(UIViewController*)vc
					 withOptions:(NSDictionary*)options
					  completion:(KNTransitionCompletionBlock)completion
					dismissBlock:(KNTransitionCompletionBlock)dismissBlock {
    [self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIViewController *targetParentVC = [self kn_parentTargetViewController];
    
	// implement view controller containment for the semi-modal view controller
	[targetParentVC addChildViewController:vc];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:YES animated:YES]; // iOS 6
	}
	objc_setAssociatedObject(self, kSemiModalViewController, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kSemiModalDismissBlock, dismissBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
	[self presentSemiView:vc.view withOptions:options completion:^{
		[vc didMoveToParentViewController:targetParentVC];
		if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
			[vc endAppearanceTransition]; // iOS 6
		}
		if (completion) {
			completion();
		}
	}];
}

-(void)presentSemiView:(UIView*)view {
	[self presentSemiView:view withOptions:nil completion:nil];
}

-(void)presentSemiView:(UIView*)view withOptions:(NSDictionary*)options {
	[self presentSemiView:view withOptions:options completion:nil];
}

-(void)presentSemiView:(UIView*)modalView
		   withOptions:(NSDictionary*)options
			completion:(KNTransitionCompletionBlock)completion {
	[self kn_registerDefaultsAndOptions:options]; // re-registering is OK
	UIView * target = [self kn_parentTarget];
	KNSemiModalContainerView *containerView = [self kn_containerViewForTarget:target];
    
    if (![target.subviews containsObject:modalView] && ![containerView.subviews containsObject:modalView]) {
        // Set associative object
        objc_setAssociatedObject(target, kSemiModalPresentingViewController, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // Register for orientation changes, so we can update the presenting controller screenshot
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(kn_interfaceOrientationDidChange:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        // Get transition style
        KNSemiModalTransitionStyle transitionStyle = [self kn_transitionInStyle];
        
        // Get the direction
        KNSemiModalTransitionDirection transitionDirection = [self kn_transitionInDirection];
        
        // Get the modal position
        KNSemiModalModalPosition modalPosition = [self kn_modalPosition];
        
        BOOL useParentWidth = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.useParentWidth] boolValue];
        
        CGFloat statusBarHeight = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.statusBarHeight] doubleValue];
        
        // Calulate all frames
        CGRect modalFrame = modalView.frame;
        
        CGFloat customWidth = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.customWidth] doubleValue];
        CGFloat customHeight = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.customHeight] doubleValue];
        
        if (customWidth > 0.0f) {
            modalFrame = CGRectSetWidth(modalFrame, customWidth);
        }
        
        if (customHeight > 0.0f) {
            modalFrame = CGRectSetHeight(modalFrame, customHeight);
        }
        
        CGFloat modalHeight = modalFrame.size.height;
        CGRect targetBounds = target.bounds;
        CGFloat targetHeight = CGRectGetHeight(targetBounds) - statusBarHeight;
        CGRect modalFrameFinal;
        CGRect modalFrameInitial;
        
        
        if (useParentWidth) {
            modalFrameFinal = CGRectMake(0.0f, 0.0f, targetBounds.size.width, modalHeight);
        } else {
            // We center the view and mantain aspect ratio
            modalFrameFinal = CGRectMake((targetBounds.size.width - modalFrame.size.width) / 2.0, 0.0f, modalFrame.size.width, modalHeight);
        }
        
        switch (modalPosition) {
            case KNSemiModalModalPositionTop:
                modalFrameFinal.origin.y = statusBarHeight;
                break;
            case KNSemiModalModalPositionCenter:
                modalFrameFinal.origin.y = statusBarHeight + floor((targetHeight - modalHeight) / 2.0f);
                break;
                
            default:
                modalFrameFinal.origin.y = statusBarHeight + targetHeight-modalHeight;
                break;
        }
        
        modalFrameInitial = modalFrameFinal;
        
        if (transitionStyle == KNSemiModalTransitionStyleFade) transitionDirection = KNSemiModalTransitionDirectionNone;
        
        switch (transitionDirection) {
            case KNSemiModalTransitionDirectionFromTop:
                modalFrameInitial.origin.y = -modalHeight;
                break;
            case KNSemiModalTransitionDirectionFromBottom:
                modalFrameInitial.origin.y = statusBarHeight + targetHeight;
                break;
            case KNSemiModalTransitionDirectionFromLeft:
                modalFrameInitial.origin.x = -CGRectGetWidth(modalFrameFinal);
                break;
            case KNSemiModalTransitionDirectionFromRight:
                modalFrameInitial.origin.x = CGRectGetWidth(targetBounds);
                break;
                
            default:
                break;
        }
        
        BOOL pushParentBack = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue];
        CGFloat parentAlpha = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.parentAlpha] floatValue];
        
        // Container
        
        containerView = [[KNSemiModalContainerView alloc] initWithFrame:targetBounds];
        containerView.backgroundColor = [UIColor clearColor];
        containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [target addSubview:containerView];
        
        objc_setAssociatedObject(self, kSemiModalModalContainerView, containerView, OBJC_ASSOCIATION_ASSIGN);
        
        // Add semi overlay
        UIView * overlay = [[UIView alloc] initWithFrame:targetBounds];
        overlay.backgroundColor = [UIColor clearColor];
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.tag = kSemiModalOverlayTag;
        
        UIView * overlayBackground = nil;
        UIView *fadedView = nil;
        
        UIColor *backgroundColor = [self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.backgroundColor];
        
        UIImageView *screenshotImageView = nil;
        
        // Take screenshot and scale
        if (pushParentBack) {
            screenshotImageView = [self kn_addOrUpdateParentScreenshotInView:overlay];
            overlay.backgroundColor = backgroundColor;
            fadedView = screenshotImageView;
        } else {
            overlayBackground = [[UIView alloc] initWithFrame:overlay.bounds];
            overlayBackground.tag = kSemiModalOverlayBackgroundTag;
            overlayBackground.backgroundColor = backgroundColor;
            overlayBackground.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            overlayBackground.alpha = 0.0f;
            
            parentAlpha = MIN(MAX(0.0f, (1.0f - parentAlpha)), 1.0f);
            fadedView = overlayBackground;
        }
        [overlay addSubview:overlayBackground];
        [containerView addSubview:overlay];
        
        // Dismiss button (if allow)
        if(![[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.disableCancel] boolValue]) {
            // Don't use UITapGestureRecognizer to avoid complex handling
            UIButton * dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [dismissButton addTarget:self action:@selector(dismissSemiModalView) forControlEvents:UIControlEventTouchUpInside];
            dismissButton.backgroundColor = [UIColor clearColor];
            dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            dismissButton.frame = overlay.bounds;
            dismissButton.tag = kSemiModalDismissButtonTag;
            [overlay addSubview:dismissButton];
        }
        
        // Begin overlay animation
		if (pushParentBack) {
			[screenshotImageView.layer addAnimation:[self animationGroupForward:YES] forKey:@"pushedBackAnimation"];
		}
		NSTimeInterval duration = [self kn_animationInDuration];
        
        [UIView animateWithDuration:duration animations:^{
            fadedView.alpha = parentAlpha;
        }];
        
        // Present view animated
        
        if (transitionStyle == KNSemiModalTransitionStyleFade) {
            modalView.alpha = 0.0;
        }
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
            // Don't resize the view width on rotating
            modalView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        } else {
            modalView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        }
        
        UIView *backingView = [[UIView alloc] initWithFrame:modalView.frame];
        backingView.userInteractionEnabled = YES;
        backingView.exclusiveTouch = YES;
        backingView.tag = kSemiModalModalBackingViewTag;
        [containerView addSubview:backingView];
        
        modalView.frame = modalFrameInitial;
        
        modalView.tag = kSemiModalModalViewTag;
        [containerView addSubview:modalView];
        modalView.layer.shadowColor = [[UIColor blackColor] CGColor];
        modalView.layer.shadowOffset = CGSizeMake(0.0f, 0.0f);
        modalView.layer.shadowRadius = 8.0;
        modalView.layer.shadowOpacity = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.shadowOpacity] floatValue];
        modalView.layer.shouldRasterize = YES;
        modalView.layer.rasterizationScale = [[UIScreen mainScreen] scale];
        
        backingView.frame = modalView.frame;
        backingView.backgroundColor = [UIColor clearColor];
        
        [UIView animateWithDuration:duration animations:^{
            modalView.frame = modalFrameFinal;
            backingView.frame = modalFrameFinal;
            modalView.alpha = 1.0;
        } completion:^(BOOL finished) {
            if (!finished) return;
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidShowNotification
                                                                object:self];
            if (completion) {
                completion();
            }
        }];
    }
}

-(void)dismissSemiModalView {
	[self dismissSemiModalViewWithCompletion:nil];
}

-(void)dismissSemiModalViewWithCompletion:(void (^)(void))completion {
    // Look for presenting controller if available
    UIViewController * prstingTgt = self;
    UIViewController * presentingController = objc_getAssociatedObject(prstingTgt.view, kSemiModalPresentingViewController);
    while (presentingController == nil && prstingTgt.parentViewController != nil) {
        prstingTgt = prstingTgt.parentViewController;
        presentingController = objc_getAssociatedObject(prstingTgt.view, kSemiModalPresentingViewController);
    }
    
    if (presentingController) {
        objc_setAssociatedObject(prstingTgt.view, kSemiModalPresentingViewController, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [presentingController dismissSemiModalViewWithCompletion:completion];
        return;
    }
    
    KNSemiModalContainerView *containerView = objc_getAssociatedObject(self, kSemiModalModalContainerView);
    objc_setAssociatedObject(self, kSemiModalModalContainerView, nil, OBJC_ASSOCIATION_ASSIGN);
    
    if (containerView == nil) {
        // Correct target for dismissal
        UIView * target = [self kn_parentTarget];
        containerView = [self kn_containerViewForTarget:target];
    }
    
    if (containerView == nil) return;
    
    UIView * modalView = [containerView.subviews objectAtIndex:2];
    UIView * backingView = [containerView.subviews objectAtIndex:1];
    UIView * overlayView = [containerView.subviews objectAtIndex:0];
	
    // Get transition style
    KNSemiModalTransitionStyle transitionStyle = [self kn_transitionOutStyle];
    
    // Get the direction
    KNSemiModalTransitionDirection transitionDirection = [self kn_transitionOutDirection];
    
    NSTimeInterval duration = [self kn_animationOutDuration];
    
	UIViewController *vc = objc_getAssociatedObject(self, kSemiModalViewController);
	KNTransitionCompletionBlock dismissBlock = objc_getAssociatedObject(self, kSemiModalDismissBlock);
    objc_setAssociatedObject(self, kSemiModalViewController, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kSemiModalDismissBlock, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
	
	// Child controller containment
	[vc willMoveToParentViewController:nil];
	if ([vc respondsToSelector:@selector(beginAppearanceTransition:animated:)]) {
		[vc beginAppearanceTransition:NO animated:YES]; // iOS 6
	}
    
    CGRect modalFrameFinal = modalView.frame;
    
    if (transitionStyle == KNSemiModalTransitionStyleFade) transitionDirection = KNSemiModalTransitionDirectionNone;
    
    switch (transitionDirection) {
        case KNSemiModalTransitionDirectionFromTop:
            modalFrameFinal.origin.y = -CGRectGetHeight(modalFrameFinal);
            break;
        case KNSemiModalTransitionDirectionFromBottom:
            modalFrameFinal.origin.y = CGRectGetHeight(containerView.bounds);
            break;
        case KNSemiModalTransitionDirectionFromLeft:
            modalFrameFinal.origin.x = -CGRectGetWidth(modalFrameFinal);
            break;
        case KNSemiModalTransitionDirectionFromRight:
            modalFrameFinal.origin.x = CGRectGetWidth(containerView.bounds);
            break;
            
        default:
            break;
    }
    
    CGFloat finalAlpha = modalView.alpha;
    
    if (transitionStyle == KNSemiModalTransitionStyleFade) finalAlpha = 0.0f;
    
    [UIView animateWithDuration:duration animations:^{
        modalView.alpha = finalAlpha;
        modalView.frame = modalFrameFinal;
    } completion:^(BOOL finished) {
        [overlayView removeFromSuperview];
        [modalView removeFromSuperview];
        [backingView removeFromSuperview];
        [containerView removeFromSuperview];
        
        // Child controller containment
        [vc removeFromParentViewController];
        if ([vc respondsToSelector:@selector(endAppearanceTransition)]) {
            [vc endAppearanceTransition];
        }
        
        if (dismissBlock) {
            dismissBlock();
        }
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    }];
    
    // Begin overlay animation
    UIImageView * screenshotView = (UIImageView*)[overlayView viewWithTag:kSemiModalScreenshotTag];
    if (screenshotView != nil) {
        if ([[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.pushParentBack] boolValue]) {
            [screenshotView.layer addAnimation:[self animationGroupForward:NO] forKey:@"bringForwardAnimation"];
        }
        [UIView animateWithDuration:duration animations:^{
            screenshotView.alpha = 1.0f;
        } completion:^(BOOL finished) {
            if(finished){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidHideNotification
                                                                    object:self];
                if (completion) {
                    completion();
                }
            }
        }];
    } else {
        UIView * overlayBackgroundView = [overlayView viewWithTag:kSemiModalOverlayBackgroundTag];
        
        [UIView animateWithDuration:duration animations:^{
            overlayBackgroundView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            if(finished){
                [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalDidHideNotification
                                                                    object:self];
                if (completion) {
                    completion();
                }
            }
        }];
    }
}

- (void)resizeSemiView:(CGSize)newSize
{
    [self resizeSemiView:newSize duration:[self kn_animationDuration]];
}

- (void)resizeSemiView:(CGSize)newSize duration:(NSTimeInterval)duration
{
    UIView * target = [self kn_parentTarget];
    
    KNSemiModalContainerView *containerView = [self kn_containerViewForTarget:target];
    
    if (containerView == nil) return;
    
    UIView * modalView = [containerView.subviews objectAtIndex:2];
    UIView * backingView = [containerView.subviews objectAtIndex:1];
    CGRect mf = modalView.frame;
    
    CGRect targetFrame = target.frame;
    
    BOOL useParentWidth = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.useParentWidth] boolValue];
    
    if (useParentWidth) newSize.width = CGRectGetWidth(targetFrame);
    
    mf.size.width = newSize.width;
    mf.size.height = newSize.height;
    
    mf.origin.x = round((CGRectGetWidth(targetFrame) - newSize.width)/2.0f);
    
    CGFloat statusBarHeight = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.statusBarHeight] doubleValue];
    // Get the modal position
    NSUInteger modalPosition = [[self ym_optionOrDefaultForKey:KNSemiModalOptionKeys.modalPosition] unsignedIntegerValue];
    if (modalPosition == KNSemiModalModalPositionTop) {
        mf.origin.y = statusBarHeight;
    } else if (modalPosition == KNSemiModalModalPositionCenter) {
        mf.origin.y = statusBarHeight + floor((targetFrame.size.height - statusBarHeight - mf.size.height)/2.0f);
    } else {
        mf.origin.y = target.frame.size.height - mf.size.height;
    }
	[UIView animateWithDuration:duration animations:^{
        modalView.frame = mf;
        backingView.frame = mf;
    } completion:^(BOOL finished) {
        if(finished){
            [[NSNotificationCenter defaultCenter] postNotificationName:kSemiModalWasResizedNotification
                                                                object:self];
        }
    }];
}

@end



#pragma mark - NSObject (YMOptionsAndDefaults)

//  NSObject+YMOptionsAndDefaults
//  Created by YangMeyer on 08.10.12.
//  Copyright (c) 2012 Yang Meyer. All rights reserved.
#import <objc/runtime.h>

@implementation NSObject (YMOptionsAndDefaults)

static char const * const kYMStandardOptionsTableName = "YMStandardOptionsTableName";
static char const * const kYMStandardDefaultsTableName = "YMStandardDefaultsTableName";

- (void)ym_registerOptions:(NSDictionary *)options
				  defaults:(NSDictionary *)defaults
{
	objc_setAssociatedObject(self, kYMStandardOptionsTableName, options, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(self, kYMStandardDefaultsTableName, defaults, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)ym_optionOrDefaultForKey:(NSString*)optionKey
{
	NSDictionary *options = objc_getAssociatedObject(self, kYMStandardOptionsTableName);
    id value = options[optionKey];
    if (value == nil) {
        NSDictionary *defaults = objc_getAssociatedObject(self, kYMStandardDefaultsTableName);
        if (!defaults) defaults = [self kn_semiModelDefaultsDictionary];
        value = defaults[optionKey];
    }
	return value;
}
@end



#pragma mark - UIView (FindUIViewController)

// Convenient category method to find actual ViewController that contains a view
// Adapted from: http://stackoverflow.com/questions/1340434/get-to-uiviewcontroller-from-uiview-on-iphone

@implementation UIView (FindUIViewController)

- (UIViewController *) containingViewController {
    UIView * target = self.superview ? self.superview : self;
    return (UIViewController *)[target traverseResponderChainForUIViewController];
}

- (id) traverseResponderChainForUIViewController {
    id nextResponder = [self nextResponder];
    BOOL isViewController = [nextResponder isKindOfClass:[UIViewController class]];
    BOOL isTabBarController = [nextResponder isKindOfClass:[UITabBarController class]];
    if (isViewController && !isTabBarController) {
        return nextResponder;
    } else if(isTabBarController){
        UITabBarController *tabBarController = nextResponder;
        return [tabBarController selectedViewController];
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForUIViewController];
    } else {
        return nil;
    }
}

@end

@implementation UIView (KNSemiModal)

- (BOOL) containedWithinSemiModalSuperview
{
    UIView *v = self;
    do {
        if ([v isKindOfClass:[KNSemiModalContainerView class]]) return YES;
        v = v.superview;
    } while (v != nil);
    return NO;
}

@end

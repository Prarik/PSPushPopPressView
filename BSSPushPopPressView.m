//
// -----------------------------------------------------------------------------
// Copyright (c) 2011 Blacksmith Software

// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
// -----------------------------------------------------------------------------
//
//  BSSPushPopPressView.m
//
//  Copyright 2011 Blacksmith Software. All rights reserved.
//  Modified by Peter Steinberger, 2011.
//

#import "BSSPushPopPressView.h"
#import <QuartzCore/QuartzCore.h>

#define kBSSAnimationDuration 0.35f
#define kBSSShadowFadeDuration 0.45f
#define kBSSAnimationMoveToOriginalPositionDuration 0.5f
#define kFullscreenAnimationBounce 20
#define kEmbeddedAnimationBounceMultiplier 0.05f

@interface BSSPushPopPressView()
@property (nonatomic, getter=isBeingDragged) BOOL beingDragged;
@property (nonatomic, getter=isFullscreen) BOOL fullscreen;
@property (nonatomic, retain) UIView *initialSuperview;
- (CGRect)windowBounds;
@end

@implementation BSSPushPopPressView

@synthesize pushPopPressViewDelegate;
@synthesize beingDragged;
@synthesize fullscreen;
@synthesize initialSuperview;
@synthesize initialFrame = initialFrame_;
@synthesize allowSingleTapSwitch;
@synthesize ignoreStatusBar;

// adapt frame for fullscreen
- (void)detectOrientation {
    if (self.isFullscreen) {
        self.frame = [self windowBounds];
    }
}

- (id) initWithFrame: (CGRect) frame_ {
    if ((self = [super initWithFrame: frame_])) {
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = YES;
        
        scaleTransform = CGAffineTransformIdentity;
        rotateTransform = CGAffineTransformIdentity;
        panTransform = CGAffineTransformIdentity;

        initialFrame_ = frame_;

        allowSingleTapSwitch = YES;

        UIPinchGestureRecognizer* pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget: self action: @selector(pinchPanRotate:)];
        pinchRecognizer.cancelsTouchesInView = NO;
        pinchRecognizer.delaysTouchesBegan = NO;
        pinchRecognizer.delaysTouchesEnded = NO;
        pinchRecognizer.delegate = self;
        [self addGestureRecognizer: pinchRecognizer];
        [pinchRecognizer release];
        
        UIRotationGestureRecognizer* rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget: self action: @selector(pinchPanRotate:)];
        rotationRecognizer.cancelsTouchesInView = NO;
        rotationRecognizer.delaysTouchesBegan = NO;
        rotationRecognizer.delaysTouchesEnded = NO;
        rotationRecognizer.delegate = self;
        [self addGestureRecognizer: rotationRecognizer];
        [rotationRecognizer release];

        panRecognizer_ = [[UIPanGestureRecognizer alloc] initWithTarget: self action: @selector(pinchPanRotate:)];
        panRecognizer_.cancelsTouchesInView = NO;
        panRecognizer_.delaysTouchesBegan = NO;
        panRecognizer_.delaysTouchesEnded = NO;
        panRecognizer_.delegate = self;
        panRecognizer_.minimumNumberOfTouches = 2;
        panRecognizer_.maximumNumberOfTouches = 2;
        [self addGestureRecognizer:panRecognizer_];
        [panRecognizer_ release];

        tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget: self action: @selector(tap:)];
        tapRecognizer.delegate = self;
        tapRecognizer.cancelsTouchesInView = NO;
        tapRecognizer.delaysTouchesBegan = NO;
        tapRecognizer.delaysTouchesEnded = NO;
        [self addGestureRecognizer: tapRecognizer];

        currentTouches = [[NSMutableSet alloc] init];

        self.layer.shadowRadius = 15.0f;
        self.layer.shadowOffset = CGSizeMake(5.0f, 5.0f);
        self.layer.shadowOpacity = 0.4f;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
        self.layer.shadowOpacity = 0.0f;

        // manually track rotations and adapt fullscreen
        // needed if we rotate within a fullscreen animation and miss the autorotate event
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectOrientation) name:UIDeviceOrientationDidChangeNotification object:nil];
    }

    return self;
}

- (void) dealloc {
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    pushPopPressViewDelegate = nil;
    [currentTouches release], currentTouches = nil;
    [tapRecognizer release];
    [super dealloc];
}

// don't manipulate initialFrame inside the view
- (void)setFrameInternal:(CGRect)frame {
    [super setFrame:frame];
}

- (void)setInitialFrame:(CGRect)initialFrame {
    initialFrame_ = initialFrame;

    // if we're not in fullscreen, re-set frame
    if (!self.isFullscreen) {
        self.frame = initialFrame;
    }
}

- (UIView *)rootView {
    return self.window.rootViewController.view;
}

- (CGRect)windowBounds {
    // completely fullscreen
    CGRect windowBounds = [self rootView].bounds;

    if (self.ignoreStatusBar) {
        windowBounds = [UIScreen mainScreen].bounds;
        if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
            windowBounds.size.width = windowBounds.size.height;
            windowBounds.size.height = [UIScreen mainScreen].bounds.size.width;
        }
        // TODO: frame still offset after rotate!
        //CGFloat statusBarOffset = [self rootView].bounds.size.height - windowBounds.size.height;
        //windowBounds.origin.y = statusBarOffset;
    }
    return windowBounds;
}

- (CGRect)superviewCorrectedInitialFrame {
    UIView *rootView = [self rootView];
    CGRect superviewCorrectedInitialFrame = [rootView convertRect:initialFrame_ fromView:self.initialSuperview];
    return superviewCorrectedInitialFrame;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (!newSuperview && self.isBeingDragged) {
        self.beingDragged = NO;

        // do we need to call the delegate?
        BOOL notYetEnded = [currentTouches count] >= 2;
        if (notYetEnded) {
            [self.pushPopPressViewDelegate bssPushPopPressViewDidFinishManipulation:self];
        }
        [currentTouches removeAllObjects];
    }
}

- (BOOL)detachViewToWindow:(BOOL)enable {
    BOOL viewChanged = NO;
    UIView *rootView = [self rootView];

    if (enable && !self.initialSuperview) {
        self.initialSuperview = self.superview;
        CGRect newFrame = [self.superview convertRect:initialFrame_ toView:rootView];
        [rootView addSubview:self];
        [self setFrameInternal:newFrame];
        viewChanged = YES;
        //NSLog(@"detached! Frame: %@", NSStringFromCGRect(newFrame));
    }else if(!enable) {
        if (self.initialSuperview) {
            [self.initialSuperview addSubview:self];
            viewChanged = YES;
        }
        [self setFrameInternal:initialFrame_];
        self.initialSuperview = nil;
    }
    return viewChanged;
}

- (void)updateShadowPath {
    self.layer.shadowPath = [UIBezierPath bezierPathWithRect:self.bounds].CGPath;
}

- (void)applyShadowAnimated:(BOOL)animated {
    if(animated) {
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        anim.fromValue = [NSNumber numberWithFloat:0.0f];
        anim.toValue = [NSNumber numberWithFloat:1.0f];
        anim.duration = kBSSShadowFadeDuration;
        [self.layer addAnimation:anim forKey:@"shadowOpacity"];
    }else {
        [self.layer removeAnimationForKey:@"shadowOpacity"];
    }

    [self updateShadowPath];
    self.layer.shadowOpacity = 1.0f;
}

- (void)removeShadowAnimated:(BOOL)animated {
    // TODO: sometimes animates cracy, shadowOpacity animation losses shadowPath transform on certain conditions
    // shadow should also use a "lightSource", maybe it's easier to make a completely custom shadow view.
    if (animated) {
        CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        anim.fromValue = [NSNumber numberWithFloat:1.0f];
        anim.toValue = [NSNumber numberWithFloat:0.0f];
        anim.duration = kBSSShadowFadeDuration;
        [self.layer addAnimation:anim forKey:@"shadowOpacity"];
    }else {
        [self.layer removeAnimationForKey:@"shadowOpacity"];
    }

    self.layer.shadowOpacity = 0.0f;
}

- (void)setBeingDragged:(BOOL)newBeingDragged {
    if (newBeingDragged != beingDragged) {
        beingDragged = newBeingDragged;

        if (beingDragged) {
            [self applyShadowAnimated:YES];
        }else {
            BOOL animate = !self.isFullscreen && !fullscreenAnimationActive;
            [self removeShadowAnimated:animate];
        }
    }
}

- (void) moveViewToOriginalPositionAnimated:(BOOL)animated bounces:(BOOL)bounces {
    CGFloat bounceX = panTransform.tx * kEmbeddedAnimationBounceMultiplier * -1;
    CGFloat bounceY = panTransform.ty * kEmbeddedAnimationBounceMultiplier * -1;

    // switch coordinates of gestureRecognizer in landscape
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        CGFloat tmp = bounceY;
        bounceY = bounceX;
        bounceX = tmp;
    }

    __block CGRect correctedInitialFrame = [self superviewCorrectedInitialFrame];
    CGFloat widthDifference = (self.frame.size.width - correctedInitialFrame.size.width) * 0.05;
    CGFloat heightDifference = (self.frame.size.height - correctedInitialFrame.size.height) * 0.05;
    self.fullscreen = NO;

    if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewWillAnimateToOriginalFrame:duration:)]) {
        [self.pushPopPressViewDelegate bssPushPopPressViewWillAnimateToOriginalFrame: self duration:kBSSAnimationMoveToOriginalPositionDuration*1.5f];
    }

    [UIView animateWithDuration: animated ? kBSSAnimationMoveToOriginalPositionDuration : 0.f delay: 0.0
                        options: UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations: ^{
                         // always reset transforms
                         rotateTransform = CGAffineTransformIdentity;
                         panTransform = CGAffineTransformIdentity;
                         scaleTransform = CGAffineTransformIdentity;
                         self.transform = CGAffineTransformIdentity;

                         if (bounces) {
                             if (abs(bounceX) > 0 || abs(bounceY) > 0) {
                                 CGRect targetFrame = CGRectMake(correctedInitialFrame.origin.x + bounceX + (widthDifference / 2.0), correctedInitialFrame.origin.y + bounceY + (heightDifference / 2.0), correctedInitialFrame.size.width + (widthDifference * -1), correctedInitialFrame.size.height + (heightDifference * -1));
                                 [self setFrameInternal:targetFrame];
                             }else {
                                 // there's reason behind this madness. shadow freaks out when we come from fullscreen, but not if we had transforms.
                                 fullscreenAnimationActive = YES;
                                 CGRect targetFrame = CGRectMake(correctedInitialFrame.origin.x + 3, correctedInitialFrame.origin.y + 3, correctedInitialFrame.size.width - 6, correctedInitialFrame.size.height - 6);
                                 //NSLog(@"targetFrame: %@ (superview: %@; initialSuperview: %@)", NSStringFromCGRect(targetFrame), self.superview, self.initialSuperview);
                                 [self setFrameInternal:targetFrame];
                             }
                         }else {
                             [self setFrameInternal:correctedInitialFrame];
                         }
                     }
                     completion: ^(BOOL finished) {
                         //NSLog(@"moveViewToOriginalPositionAnimated [complete] finished:%d, bounces:%d", finished, bounces);
                         fullscreenAnimationActive = NO;
                         correctedInitialFrame = [self superviewCorrectedInitialFrame];
                         if (bounces && finished) {
                             [UIView animateWithDuration: kBSSAnimationMoveToOriginalPositionDuration/2 delay: 0.0
                                                 options:UIViewAnimationOptionAllowUserInteraction animations: ^{
                                                     [self setFrameInternal:correctedInitialFrame];
                                                 } completion: ^(BOOL finished) {
                                                     if (finished && !self.isBeingDragged) {
                                                         [self detachViewToWindow:NO];
                                                     }
                                                     if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewDidAnimateToOriginalFrame:)]) {
                                                         [self.pushPopPressViewDelegate bssPushPopPressViewDidAnimateToOriginalFrame: self];
                                                     }
                                                 }];
                         }else {
                             if (!self.isBeingDragged) {
                                 [self detachViewToWindow:NO];
                             }
                             if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewDidAnimateToOriginalFrame:)]) {
                                 [self.pushPopPressViewDelegate bssPushPopPressViewDidAnimateToOriginalFrame: self];
                             }
                         }
                     }];
}

- (void)moveToFullscreenAnimated:(BOOL)animated bounces:(BOOL)bounces {
    if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewWillAnimateToFullscreenWindowFrame:duration:)]) {
        [self.pushPopPressViewDelegate bssPushPopPressViewWillAnimateToFullscreenWindowFrame: self duration: kBSSAnimationDuration];
    }

    BOOL viewChanged = [self detachViewToWindow:YES];
    self.fullscreen = YES;

    __block CGRect windowBounds = [self windowBounds];
    [UIView animateWithDuration: animated ? kBSSAnimationDuration : 0.f delay: 0.0
                        // view hierarchy change needs some time propagating, don't use UIViewAnimationOptionBeginFromCurrentState when just changed
                        options: (viewChanged ? 0 : UIViewAnimationOptionBeginFromCurrentState) | UIViewAnimationOptionAllowUserInteraction
                     animations: ^{
                         scaleTransform = CGAffineTransformIdentity;
                         rotateTransform = CGAffineTransformIdentity;
                         panTransform = CGAffineTransformIdentity;
                         self.transform = CGAffineTransformIdentity;
                         if (bounces) {
                             [self setFrameInternal:CGRectMake(windowBounds.origin.x - kFullscreenAnimationBounce, windowBounds.origin.y - kFullscreenAnimationBounce, windowBounds.size.width + kFullscreenAnimationBounce*2, windowBounds.size.height + kFullscreenAnimationBounce*2)];
                         }else {
                             [self setFrameInternal:[self windowBounds]];
                         }
                     }
                     completion: ^(BOOL finished) {
                         windowBounds = [self windowBounds];
                         if (bounces && finished) {
                             [UIView animateWithDuration:kBSSAnimationDuration delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
                                 [self setFrameInternal:windowBounds];
                             } completion:^(BOOL finished) {
                                 if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewDidAnimateToFullscreenWindowFrame:)]) {
                                     [self.pushPopPressViewDelegate bssPushPopPressViewDidAnimateToFullscreenWindowFrame: self];
                                 }
                             }];
                         }else {
                         if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewDidAnimateToFullscreenWindowFrame:)]) {
                             [self.pushPopPressViewDelegate bssPushPopPressViewDidAnimateToFullscreenWindowFrame: self];
                         }
                         }
                     }];
}

- (void)alignViewAnimated:(BOOL)animated bounces:(BOOL)bounces {
    if (self.frame.size.width > ([self windowBounds].size.width)) {
        [self moveToFullscreenAnimated:animated bounces:bounces];
    } else {
        [self moveViewToOriginalPositionAnimated:animated bounces:bounces];
    }
}

// disrupt gesture recognizer, which continues to receive touch events even as we set minimumNumberOfTouches to two.
- (void)resetGestureRecognizers {
    panRecognizer_.enabled = NO;
    panRecognizer_.enabled = YES;

    // if gestures haven't yet ended, but we're disrupted, align view anyway
    if (!gesturesEnded) {
        [self alignViewAnimated:YES bounces:YES];
    }
}

- (void) startedGesture:(UIGestureRecognizer *)gesture {
    [self detachViewToWindow:YES];
    UIPinchGestureRecognizer *pinch = [gesture isKindOfClass:[UIPinchGestureRecognizer class]] ? (UIPinchGestureRecognizer *)gesture : nil;
    gesturesEnded = NO;
    if (pinch) {
        scaleActive = YES;
    }
}

/*
 When one gesture ends, the whole view manipulation is ended. In case the user also started a pinch and the pinch is still active, we wait for the pinch to finish as we want to check for a fast pinch movement to open the view in fullscreen or not. If no pinch is active, we can end the manipulation as soon as the first gesture ended.
 */
- (void)endedGesture:(UIGestureRecognizer *)gesture {
    if (gesturesEnded) return;
    
    UIPinchGestureRecognizer *pinch = [gesture isKindOfClass:[UIPinchGestureRecognizer class]] ? (UIPinchGestureRecognizer *)gesture : nil;
    if (scaleActive == YES && pinch == nil) return;
    
    gesturesEnded = YES;        
    if (pinch) {
        scaleActive = NO;
        if (pinch.velocity >= 2.0f) {
            [self moveToFullscreenAnimated:YES bounces:YES];
        } else {
            [self alignViewAnimated:YES bounces:YES];
        }
    } else {
        [self alignViewAnimated:YES bounces:YES];
    }
}

- (void) modifiedGesture:(UIGestureRecognizer *)gesture {
    if ([gesture isKindOfClass:[UIPinchGestureRecognizer class]]) {
        UIPinchGestureRecognizer *pinch = (UIPinchGestureRecognizer *)gesture;
        scaleTransform = CGAffineTransformScale(CGAffineTransformIdentity, pinch.scale, pinch.scale);
    }
    else if ([gesture isKindOfClass:[UIRotationGestureRecognizer class]]) {
        UIRotationGestureRecognizer *rotate = (UIRotationGestureRecognizer *)gesture;
        rotateTransform = CGAffineTransformRotate(CGAffineTransformIdentity, rotate.rotation);
    }
    else if ([gesture isKindOfClass:[UIPanGestureRecognizer class]]) {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
        CGPoint translation = [pan translationInView: self.superview];
        panTransform = CGAffineTransformTranslate(CGAffineTransformIdentity, translation.x, translation.y);
    }
    
    self.transform = CGAffineTransformConcat(CGAffineTransformConcat(scaleTransform, rotateTransform), panTransform);
}

// scale and rotation transforms are applied relative to the layer's anchor point
// this method moves a gesture recognizer's view's anchor point between the user's fingers
- (void)adjustAnchorPointForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIView *piece = gestureRecognizer.view;
        CGPoint locationInView = [gestureRecognizer locationInView:piece];
        CGPoint locationInSuperview = [gestureRecognizer locationInView:piece.superview];

        piece.layer.anchorPoint = CGPointMake(locationInView.x / piece.bounds.size.width, locationInView.y / piece.bounds.size.height);
        piece.center = locationInSuperview;
    }
}

- (void) pinchPanRotate: (UIGestureRecognizer*) gesture {
    [self adjustAnchorPointForGestureRecognizer:gesture];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: { 
            [self startedGesture:gesture];
            break; }
        case UIGestureRecognizerStatePossible: { break; }
        case UIGestureRecognizerStateCancelled: {
            [self endedGesture:gesture];
        } break;
        case UIGestureRecognizerStateFailed: { 
        } break; 
        case UIGestureRecognizerStateChanged: {
            [self modifiedGesture:gesture];
            break;
        }
        case UIGestureRecognizerStateEnded: {
            [self endedGesture:gesture];
            break; 
        }
    }
}

- (void) tap: (UITapGestureRecognizer*) tap {
    if (self.allowSingleTapSwitch) {
        if (tap.state == UIGestureRecognizerStateEnded) {
            if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewDidReceiveTap:)]) {
                [self.pushPopPressViewDelegate bssPushPopPressViewDidReceiveTap: self];
            }

            if (!self.isFullscreen) {
                [self moveToFullscreenWindowAnimated:YES];
            } else {
                [self moveToOriginalFrameAnimated:YES];
            }
        }
    }
}

- (BOOL) gestureRecognizer: (UIGestureRecognizer*) gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer: (UIGestureRecognizer*) otherGestureRecognizer {
    // if the gesture recognizers's view isn't one of our pieces, don't allow simultaneous recognition
    if (gestureRecognizer.view != self)
        return NO;

    // if the gesture recognizers are on different views, don't allow simultaneous recognition
    if (gestureRecognizer.view != otherGestureRecognizer.view)
        return NO;

    return YES;
}

- (BOOL) gestureRecognizer: (UIGestureRecognizer*) gestureRecognizer shouldReceiveTouch: (UITouch*) touch {
    if ([gestureRecognizer isKindOfClass: [UITapGestureRecognizer class]] && [touch.view isKindOfClass: [UIButton class]]) {
        return NO;
    }
    return YES;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // sometimes, the system gets confused and doesn't send us touchesEnded/touchesCancelled-Events. Compensate and filter cancelled touches.
    NSSet *cancelledTouches = [currentTouches filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"phase = %d", UITouchPhaseCancelled]];
    [currentTouches minusSet:cancelledTouches];

    BOOL notYetStarted = [currentTouches count] < 2;
    [currentTouches unionSet:touches];
    if (notYetStarted && [currentTouches count] >= 2) {
        self.beingDragged = YES;
        [self.pushPopPressViewDelegate bssPushPopPressViewDidStartManipulation: self];
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    self.beingDragged = NO;
    BOOL notYetEnded = [currentTouches count] >= 2;
    [currentTouches minusSet:touches];
    if (notYetEnded && [currentTouches count] < 2) {
        [self resetGestureRecognizers];
        [self.pushPopPressViewDelegate bssPushPopPressViewDidFinishManipulation: self];
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    self.beingDragged = NO;
    BOOL notYetEnded = [currentTouches count] >= 2;
    [currentTouches minusSet:touches];
    if (notYetEnded && [currentTouches count] < 2) {
        [self resetGestureRecognizers];
        [self.pushPopPressViewDelegate bssPushPopPressViewDidFinishManipulation: self];
    }
}

- (void)moveToFullscreenWindowAnimated:(BOOL)animated {
    if (self.isFullscreen) return;

    if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewShouldAllowTapToAnimateToFullscreenWindowFrame:)]) {
        if ([self.pushPopPressViewDelegate bssPushPopPressViewShouldAllowTapToAnimateToFullscreenWindowFrame: self] == NO) return;
    }

    [self moveToFullscreenAnimated:animated bounces:YES];
}

- (void)moveToOriginalFrameAnimated:(BOOL)animated {
    if (self.isFullscreen == NO) return;

    if ([self.pushPopPressViewDelegate respondsToSelector: @selector(bssPushPopPressViewShouldAllowTapToAnimateToOriginalFrame:)]) {
        if ([self.pushPopPressViewDelegate bssPushPopPressViewShouldAllowTapToAnimateToOriginalFrame: self] == NO) return;
    }

    [self moveViewToOriginalPositionAnimated:animated bounces:YES];
}

// enable/disable single tap detection
- (void)setAllowSingleTapSwitch:(BOOL)newAllowSingleTapSwitch {
    if (allowSingleTapSwitch != newAllowSingleTapSwitch) {
        allowSingleTapSwitch = newAllowSingleTapSwitch;
        tapRecognizer.enabled = newAllowSingleTapSwitch;
    }
}

@end

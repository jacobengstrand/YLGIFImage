//
//  YLImageView.m
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//

#import "YLImageView.h"
#import "YLGIFImage.h"
#import <QuartzCore/QuartzCore.h>

#define kGMCFCoreFoundationVersionNumber_iPhoneOS_8_0 1140.100000

@interface YLImageView ()

@property (nonatomic, strong) YLGIFImage *animatedImage;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic) NSTimeInterval accumulator;
@property (nonatomic) NSUInteger currentFrameIndex;
@property (nonatomic, strong) UIImage* currentFrame;
@property (nonatomic) NSUInteger loopCountdown;
@property (nonatomic) BOOL wantsToAnimate;
@property (nonatomic) BOOL shouldAnimate;

@end

@implementation YLImageView

const NSTimeInterval kMaxTimeStep = 1; // note: To avoid spiral-o-death

@synthesize runLoopMode = _runLoopMode;



- (void)setUpNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleUIApplicationDidBecomeActiveNotification)
												 name:UIApplicationDidBecomeActiveNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleUIApplicationWillResignActiveNotification)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
}



- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



- (void)setupDisplayLink
{
	if (!_displayLink && self.animatedImage) {
		_displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(changeKeyframe:)];
		[_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:self.runLoopMode];
	}
}



- (NSString *)runLoopMode
{
    return _runLoopMode ?: NSRunLoopCommonModes;
}



- (void)setRunLoopMode:(NSString *)runLoopMode
{
    if (runLoopMode != _runLoopMode) {
        [self stopAnimating];
        
        NSRunLoop *runloop = [NSRunLoop mainRunLoop];
        [_displayLink removeFromRunLoop:runloop forMode:_runLoopMode];
        [_displayLink addToRunLoop:runloop forMode:runLoopMode];
        
        _runLoopMode = runLoopMode;
		
		[self startAnimatingIfAppropriate];
	}
}

- (void)setImage:(UIImage *)image
{
    if (image == self.image) {
        return;
    }
    
    [self stopAnimating];
    
    self.currentFrameIndex = 0;
    self.loopCountdown = 0;
    self.accumulator = 0;
	
	[self setUpNotifications];
	_shouldAnimate = ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive);

    if ([image isKindOfClass:[YLGIFImage class]] && image.images) {
		if (kCFCoreFoundationVersionNumber >= kGMCFCoreFoundationVersionNumber_iPhoneOS_8_0) {
			if ([image.images[0] isKindOfClass:[UIImage class]])
				[super setImage:image.images[0]];
			else
				[super setImage:nil];
		}
		else {
			// iOS 7 or earlier.
			[super setImage:nil];
		}
        self.currentFrame = nil;
        self.animatedImage = (YLGIFImage *)image;
        self.loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
    } else {
        self.animatedImage = nil;
        [super setImage:image];
    }
    [self.layer setNeedsDisplay];
}

- (void)setAnimatedImage:(YLGIFImage *)animatedImage
{
    _animatedImage = animatedImage;
    if (animatedImage == nil) {
        self.layer.contents = nil;
    }
}

- (BOOL)isAnimating
{
    return [super isAnimating] || (_displayLink && !_displayLink.isPaused);
}

- (void)stopAnimating
{
    if (!self.animatedImage) {
        [super stopAnimating];
        return;
    }
 
	_wantsToAnimate = NO;
    _displayLink.paused = YES;
}



- (void)startAnimatingIfAppropriate
{
	if (!self.animatedImage) {
		[super startAnimating];
		return;
	}
	
	if (self.isAnimating) {
		return;
	}
	
	if (_wantsToAnimate && _shouldAnimate) {
		[self setupDisplayLink];
		self.loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
		self.displayLink.paused = NO;
	}
}



- (void)startAnimating
{
	_wantsToAnimate = YES;
	[self startAnimatingIfAppropriate];
}



- (void)changeKeyframe:(CADisplayLink *)displayLink
{
    if (self.currentFrameIndex >= [self.animatedImage.images count]) {
        return;
    }
    self.accumulator += fmin(displayLink.duration, kMaxTimeStep);
    
    while (self.accumulator >= self.animatedImage.frameDurations[self.currentFrameIndex]) {
        self.accumulator -= self.animatedImage.frameDurations[self.currentFrameIndex];
        if (++self.currentFrameIndex >= [self.animatedImage.images count]) {
            if (--self.loopCountdown == 0) {
                [self stopAnimating];
                return;
            }
            self.currentFrameIndex = 0;
        }
        self.currentFrameIndex = MIN(self.currentFrameIndex, [self.animatedImage.images count] - 1);
        self.currentFrame = [self.animatedImage getFrameWithIndex:self.currentFrameIndex
														  preload:YES];
		[self.layer setNeedsDisplay];
	}
}

- (void)displayLayer:(CALayer *)layer
{
    if (!self.animatedImage || [self.animatedImage.images count] == 0) {
        return;
    }
    //NSLog(@"display index: %luu", (unsigned long)self.currentFrameIndex);
    if(self.currentFrame && ![self.currentFrame isKindOfClass:[NSNull class]])
        layer.contents = (__bridge id)([self.currentFrame CGImage]);
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window) {
		[self startAnimatingIfAppropriate];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.window) {
                [self stopAnimating];
            }
        });
    }
}



- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    if (! self.superview) {
		//Doesn't have superview, let's check later if we need to remove the displayLink
        dispatch_async(dispatch_get_main_queue(), ^{
			if (self.superview != nil) {
				[_displayLink invalidate];
				_displayLink = nil;
			}
		});
    }
}



- (void)setHighlighted:(BOOL)highlighted
{
    if (!self.animatedImage) {
        [super setHighlighted:highlighted];
    }
}

- (UIImage *)image
{
    return self.animatedImage ?: [super image];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    return self.image.size;
}




- (void)handleUIApplicationDidBecomeActiveNotification
{
	_shouldAnimate = YES;
	[self startAnimatingIfAppropriate];
}



- (void)handleUIApplicationWillResignActiveNotification
{
	_shouldAnimate = NO;
	_displayLink.paused = YES;
}



@end



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
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(handleUIApplicationDidReceiveMemoryWarningNotification)
												 name:UIApplicationDidReceiveMemoryWarningNotification
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
    
    _currentFrameIndex = 0;
    _loopCountdown = 0;
    _accumulator = 0;
	
	[self setUpNotifications];
	_shouldAnimate = ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive);

    if ([image isKindOfClass:[YLGIFImage class]] && image.images) {
		if (kCFCoreFoundationVersionNumber >= kGMCFCoreFoundationVersionNumber_iPhoneOS_8_0) {
			UIImage *firstFrame = [(YLGIFImage*)image getFrameWithIndex:0
																preload:NO];
			if ([firstFrame isKindOfClass:[UIImage class]])
				[super setImage:firstFrame];
			else
				[super setImage:nil];
		}
		else {
			// iOS 7 or earlier.
			[super setImage:nil];
		}
        self.currentFrame = nil;
        self.animatedImage = (YLGIFImage *)image;
        _loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
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
	[_animatedImage dropPrefetchedFrames];
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
		_loopCountdown = self.animatedImage.loopCount ?: NSUIntegerMax;
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
    if (_currentFrameIndex >= [self.animatedImage.images count]) {
        return;
    }
    _accumulator += fmin(displayLink.duration, kMaxTimeStep);
	
	NSTimeInterval duration = self.animatedImage.frameDurations[_currentFrameIndex];
    while (_accumulator >= duration) {
        _accumulator -= duration;
		if (++_currentFrameIndex >= [self.animatedImage.images count]) {
            if (--_loopCountdown == 0) {
                [self stopAnimating];
                return;
            }
            _currentFrameIndex = 0;
        }
        _currentFrameIndex = MIN(_currentFrameIndex, [self.animatedImage.images count] - 1);
        self.currentFrame = [self.animatedImage getFrameWithIndex:_currentFrameIndex
														  preload:YES];
		[self.layer setNeedsDisplay];
	}
}

- (void)displayLayer:(CALayer *)layer
{
    if (!self.animatedImage || [self.animatedImage.images count] == 0) {
        return;
    }

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
	[_animatedImage dropPrefetchedFrames];
}



- (void)handleUIApplicationDidReceiveMemoryWarningNotification
{
	if (_animatedImage != nil) {
		if (! self.isAnimating) {
			[_animatedImage dropPrefetchedFrames];
		}
	}
}



@end



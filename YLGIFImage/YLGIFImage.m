//
//  YLGIFImage.m
//  YLGIFImage
//
//  Created by Yong Li on 14-3-2.
//  Copyright (c) 2014年 Yong Li. All rights reserved.
//

#import "YLGIFImage.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>


//Define FLT_EPSILON because, reasons.
//Actually, I don't know why but it seems under certain circumstances it is not defined
#ifndef FLT_EPSILON
#define FLT_EPSILON __FLT_EPSILON__
#endif

inline static NSTimeInterval CGImageSourceGetGifFrameDelay(CGImageSourceRef imageSource, NSUInteger index)
{
    NSTimeInterval frameDuration = 0;
    CFDictionaryRef theImageProperties;
    if ((theImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, index, NULL))) {
        CFDictionaryRef gifProperties;
        if (CFDictionaryGetValueIfPresent(theImageProperties, kCGImagePropertyGIFDictionary, (const void **)&gifProperties)) {
            const void *frameDurationValue;
            if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFUnclampedDelayTime, &frameDurationValue)) {
                frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                if (frameDuration <= 0) {
                    if (CFDictionaryGetValueIfPresent(gifProperties, kCGImagePropertyGIFDelayTime, &frameDurationValue)) {
                        frameDuration = [(__bridge NSNumber *)frameDurationValue doubleValue];
                    }
                }
            }
        }
        CFRelease(theImageProperties);
    }
    
#ifndef OLExactGIFRepresentation
    //Implement as Browsers do.
    //See:  http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser-compatibility
    //Also: http://blogs.msdn.com/b/ieinternals/archive/2010/06/08/animated-gifs-slow-down-to-under-20-frames-per-second.aspx
    
    if (frameDuration < 0.02 - FLT_EPSILON) {
        frameDuration = 0.1;
    }
#endif
    return frameDuration;
}

inline static BOOL CGImageSourceContainsAnimatedGif(CGImageSourceRef imageSource)
{
    return imageSource && UTTypeConformsTo(CGImageSourceGetType(imageSource), kUTTypeGIF) && CGImageSourceGetCount(imageSource) > 1;
}

inline static BOOL isRetinaFilePath(NSString *path)
{
    NSRange retinaSuffixRange = [[path lastPathComponent] rangeOfString:@"@2x" options:NSCaseInsensitiveSearch];
    return retinaSuffixRange.length && retinaSuffixRange.location != NSNotFound;
}

@interface YLGIFImage ()

@property (nonatomic, readwrite) NSMutableArray *images;
@property (nonatomic, readwrite) NSTimeInterval *frameDurations;
@property (nonatomic, readwrite) NSTimeInterval totalDuration;
@property (nonatomic, readwrite) NSUInteger loopCount;
@property (nonatomic, readwrite) CGImageSourceRef incrementalSource;
@property (nonatomic, readwrite) NSUInteger prefetchedNum;

@end

@implementation YLGIFImage
{
    dispatch_queue_t readFrameQueue;
    CGImageSourceRef _imageSourceRef;
    CGFloat _scale;
	BOOL _doneSettingUp;
}

@synthesize images;

#pragma mark - Class Methods

+ (id)imageNamed:(NSString *)name
{
    NSString *path = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:name];
    
    return ([[NSFileManager defaultManager] fileExistsAtPath:path]) ? [self imageWithContentsOfFile:path] : nil;
}

+ (id)imageWithContentsOfFile:(NSString *)path
{
    return [self imageWithData:[NSData dataWithContentsOfFile:path]
                         scale:isRetinaFilePath(path) ? 2.0f : 1.0f];
}

+ (id)imageWithData:(NSData *)data
{
    return [self imageWithData:data scale:1.0f];
}

+ (id)imageWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)(data), NULL);
    UIImage *image;
    
    if (CGImageSourceContainsAnimatedGif(imageSource)) {
        image = [[self alloc] initWithCGImageSource:imageSource scale:scale];
    } else {
        image = [super imageWithData:data scale:scale];
    }
    
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    return image;
}

#pragma mark - Initialization methods

- (id)initWithContentsOfFile:(NSString *)path
{
    return [self initWithData:[NSData dataWithContentsOfFile:path]
                        scale:isRetinaFilePath(path) ? 2.0f : 1.0f];
}

- (id)initWithData:(NSData *)data
{
    return [self initWithData:data scale:1.0f];
}

- (id)initWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) {
        return nil;
    }
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)(data), NULL);
    
    if (CGImageSourceContainsAnimatedGif(imageSource)) {
        self = [self initWithCGImageSource:imageSource scale:scale];
    } else {
        if (scale == 1.0f) {
            self = [super initWithData:data];
        } else {
            self = [super initWithData:data scale:scale];
        }
    }
    
    if (imageSource) {
        CFRelease(imageSource);
    }
    
    return self;
}

- (id)initWithCGImageSource:(CGImageSourceRef)imageSource scale:(CGFloat)scale
{
    self = [super init];
    if (!imageSource || !self) {
        return nil;
    }
	
	_prefetchedNum = 2;
	
    CFRetain(imageSource);
    
    NSUInteger numberOfFrames = CGImageSourceGetCount(imageSource);
    
    NSDictionary *imageProperties = CFBridgingRelease(CGImageSourceCopyProperties(imageSource, NULL));
    NSDictionary *gifProperties = [imageProperties objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
    
    self.frameDurations = (NSTimeInterval *)malloc(numberOfFrames  * sizeof(NSTimeInterval));
    self.loopCount = [gifProperties[(NSString *)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
    self.images = [NSMutableArray arrayWithCapacity:numberOfFrames];
	
	_scale = scale;
	readFrameQueue = dispatch_queue_create("com.ronnie.gifreadframe", DISPATCH_QUEUE_SERIAL);

	dispatch_async(readFrameQueue, ^{
		@synchronized(self.images) {
			NSNull *aNull = [NSNull null];
			NSTimeInterval frameDuration = CGImageSourceGetGifFrameDelay(imageSource, 0);
			for (NSUInteger i = 0; i < numberOfFrames; ++i) {
				[self.images addObject:aNull];
				self.frameDurations[i] = frameDuration; // Assume that all frames have the same duration.
			}
			_totalDuration = frameDuration * numberOfFrames;
			
			// Load first frame only
			CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
			[self.images replaceObjectAtIndex:0 withObject:[UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp]];
			
			// Find out how many frames we can prefetch and keep in RAM.
			NSUInteger frameDataSize = [YLGIFImage sizeOfImageRef:image];
			NSLog(@"dataSize %d: %lu", 0, frameDataSize);
			NSLog(@"frames %lu", numberOfFrames);
			NSUInteger totalSize = numberOfFrames * frameDataSize;
			NSLog(@"totalSize %lu", totalSize);
			NSUInteger maxPrefetchedNum = (NSUInteger)floor(2000000.0 / frameDataSize); // Prefetched frames should use max 2 MB RAM in total.
			if (maxPrefetchedNum < numberOfFrames) {
				// If we can't keep all frames in RAM, the CPU will have to decode each frame over and over anyway,
				// so lets not waste RAM by keeping lots of prefetched frames in memory.
				_prefetchedNum = 2;
			}
			else {
				// All frames will fit in RAM, so lets not waste CPU decoding them over and over. Prefetch all.
				_prefetchedNum = numberOfFrames;
			}
			NSLog(@"_prefetchedNum %lu", _prefetchedNum);
			
			CFRelease(image);
			CFRelease(imageSource);
		}
		_doneSettingUp = YES;

		
		// Figure out the actual diration.
		NSTimeInterval tot = 0;
		for (NSUInteger i = 0; i < numberOfFrames; ++i) {
			NSTimeInterval frameDuration = CGImageSourceGetGifFrameDelay(imageSource, i);
			self.frameDurations[i] = frameDuration;
			tot += frameDuration;
		}
		_totalDuration = tot;
	});
	
    _imageSourceRef = imageSource;
    CFRetain(_imageSourceRef);
	
    return self;
}


- (void) waitForInitialization
{
	while (! _doneSettingUp) {
		// Need to wait for initialization.
		[NSThread sleepForTimeInterval:0.0001];
	}
}



- (UIImage*)getFrameWithIndex:(NSUInteger)idx
				   preload:(BOOL)shouldPreload
{
    UIImage* frame = nil;
	
	[self waitForInitialization];

	@synchronized(self.images) {
		frame = self.images[idx];
	}

	if([frame isKindOfClass:[NSNull class]]) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, idx, NULL);
        frame = [UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp];
        CFRelease(image);
    }
	
    if (shouldPreload) {
        if(idx != 0) {
			if (self.images.count > _prefetchedNum) {
				@synchronized(self.images) {
					[self.images replaceObjectAtIndex:idx withObject:[NSNull null]];
				}
			}
        }
		
        NSUInteger nextReadIdx = (idx + _prefetchedNum);
        for(NSUInteger i=idx+1; i<=nextReadIdx; i++) {
            NSUInteger _idx = i%self.images.count;
            if([self.images[_idx] isKindOfClass:[NSNull class]]) {
                dispatch_async(readFrameQueue, ^{
                    CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, _idx, NULL);
                    @synchronized(self.images) {
                        [self.images replaceObjectAtIndex:_idx withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
                    }
                    CFRelease(image);
                });
            }
        }
    }
	
    return frame;
}


- (void)dropPrefetchedFrames
{
	[self waitForInitialization];

	NSUInteger c = self.images.count;
	@synchronized(self.images) {
		for (NSUInteger i = 1; i < c; i++) {
			if (! [self.images[i] isKindOfClass:[NSNull class]]) {
				[self.images replaceObjectAtIndex:i
									   withObject:[NSNull null]];
			}
		}
	}
}


#pragma mark - Compatibility methods

- (CGSize)size
{
	[self waitForInitialization];

    if (self.images.count) {
        return [[self.images objectAtIndex:0] size];
    }
    return [super size];
}

- (CGImageRef)CGImage
{
	[self waitForInitialization];

    if (self.images.count) {
        return [[self.images objectAtIndex:0] CGImage];
    } else {
        return [super CGImage];
    }
}

- (UIImageOrientation)imageOrientation
{
	[self waitForInitialization];

    if (self.images.count) {
        return [[self.images objectAtIndex:0] imageOrientation];
    } else {
        return [super imageOrientation];
    }
}

- (CGFloat)scale
{
	[self waitForInitialization];
	
	if (self.images.count) {
        return [(UIImage *)[self.images objectAtIndex:0] scale];
    } else {
        return [super scale];
    }
}

- (NSTimeInterval)duration
{
	[self waitForInitialization];

    return self.images ? self.totalDuration : [super duration];
}



+ (NSUInteger)sizeOfImageRef:(CGImageRef)image
{
	size_t height = CGImageGetHeight(image);
	NSUInteger bytesPerRow = CGImageGetBytesPerRow(image);
	if (bytesPerRow % 16)
		bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
	NSUInteger dataSize = height * bytesPerRow;
	
	return dataSize;
}



- (void)dealloc {
    if(_imageSourceRef) {
        CFRelease(_imageSourceRef);
    }
    free(_frameDurations);
    if (_incrementalSource) {
        CFRelease(_incrementalSource);
    }
}

@end
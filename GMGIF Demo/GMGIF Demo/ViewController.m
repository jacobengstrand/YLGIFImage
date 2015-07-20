//
//  ViewController.m
//  GMGIF Demo
//

#import "ViewController.h"
#import "YLGIFImage.h"



@implementation ViewController



- (void)viewDidLoad {
	[super viewDidLoad];
	
//	YLGIFImage *img = (YLGIFImage*)[YLGIFImage imageNamed:@"monday.gif"];
//	YLGIFImage *img = (YLGIFImage*)[YLGIFImage imageNamed:@"gum.gif"];
	YLGIFImage *img = (YLGIFImage*)[YLGIFImage imageNamed:@"joy.gif"];
	[_imageView setImage:img];
	_imageView.delegate = self;
	
	_slider.minimumValue = 0;
	_slider.maximumValue = img.images.count;
	[_slider addTarget:self
				action:@selector(handleNewSliderValue:)
	  forControlEvents:UIControlEventValueChanged];

	[self updateButton];
}



- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}



- (void)updateButton
{
	if (_imageView.isAnimating)
		[_play setTitle:@"Stop"
			   forState:UIControlStateNormal];
	else
		[_play setTitle:@"Start"
			   forState:UIControlStateNormal];
}



- (void)handleNewSliderValue: (id)sender
{
	[_imageView stopAnimating];
	NSUInteger idx = (NSUInteger)roundf(_slider.value);
	[_imageView showFrameIndex:idx];
}



#pragma mark - YLImageView callbacks



- (void)gifImageView:(YLImageView*)view didShowFrameIndex:(NSUInteger)frameIdx
{
	_slider.value = frameIdx;
}



- (void)gifImageViewDidStartAnimating:(YLImageView*)view
{
	[self updateButton];
}



- (void)gifImageViewDidStopAnimating:(YLImageView*)view
{
	[self updateButton];
}




#pragma mark - public



- (IBAction)userDidTapPlay:(id)sender;
{
	if (_imageView.isAnimating)
		[_imageView stopAnimating];
	else
		[_imageView startAnimating];
}



@end



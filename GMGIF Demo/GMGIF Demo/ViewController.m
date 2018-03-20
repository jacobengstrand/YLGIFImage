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



- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	
	CGRect viewB = self.view.bounds;
	
	CGSize imageSize = _imageView.image.size;
	CGFloat aspect = imageSize.width / imageSize.height;
	
	CGRect videoF = _imageView.frame;
	videoF.origin.x = 20;
	videoF.size.width = viewB.size.width - 2 * videoF.origin.x;
	videoF.size.height = ceil(videoF.size.width / aspect);
	_imageView.frame = videoF;
	
	CGRect buttonF = _play.frame;
	buttonF.origin.x = CGRectGetMinX(videoF);
	buttonF.origin.y = CGRectGetMaxY(videoF) + 20;
	buttonF.size.width = videoF.size.width;
	_play.frame = buttonF;
	
	CGRect sliderF = _slider.frame;
	sliderF.origin.x = CGRectGetMinX(videoF);
	sliderF.origin.y = CGRectGetMaxY(buttonF) + 20;
	sliderF.size.width = videoF.size.width;
	_slider.frame = sliderF;

//	_imageView.layer.borderWidth = 2;
//	_imageView.layer.borderColor = [UIColor greenColor].CGColor;
//	_play.layer.borderWidth = 2;
//	_play.layer.borderColor = [UIColor redColor].CGColor;
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



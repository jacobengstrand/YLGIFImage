//
//  ViewController.m
//  GMGIF Demo
//

#import "ViewController.h"
#import "YLGIFImage.h"



@implementation ViewController



- (void)viewDidLoad {
	[super viewDidLoad];
	
	YLGIFImage *img = (YLGIFImage*)[YLGIFImage imageNamed:@"joy.gif"];
	[_imageView setImage:img];

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

#pragma mark - public



- (IBAction)userDidTapPlay:(id)sender;
{
	if (_imageView.isAnimating)
		[_imageView stopAnimating];
	else
		[_imageView startAnimating];

	[self updateButton];
}



@end



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
	[_imageView startAnimating];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

@end

//
//  ViewController.h
//  GMGIF Demo
//



#import <UIKit/UIKit.h>
#import "YLImageView.h"



@interface ViewController : UIViewController <YLImageViewDelegate>

@property (nonatomic) IBOutlet YLImageView *imageView;
@property (nonatomic) IBOutlet UIButton *play;
@property (nonatomic) IBOutlet UISlider *slider;

- (IBAction)userDidTapPlay:(id)sender;
@end



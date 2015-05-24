//
//  ViewController.h
//  GMGIF Demo
//



#import <UIKit/UIKit.h>
#import "YLImageView.h"



@interface ViewController : UIViewController

@property (nonatomic) IBOutlet YLImageView *imageView;
@property (nonatomic) IBOutlet UIButton *play;

- (IBAction)userDidTapPlay:(id)sender;
@end



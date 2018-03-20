YLGIFImage
==========

####This is a greatly enhanced fork of the original YLGIFImage project.

The bugs in the original project have been fixed, the GIF player is much more efficient, and new features have been added.

<img src="./GMGIF%20Demo/joy.gif" align="middle" width="320" />

####Enhancements
• Bugfixes. No more crashing on malformed GIF files, for instance.

• Much smarter about memory usage. Only prefetches and decodes frames if the whole animation can fit under the memory limit (set to 2MB but you can change it to whatever you want).

• Animations stop when app is put in backround, and cached frames are released.

• Animations restart when app returns to the foreground.

• Delegate callbacks via an optional protocol:

    @protocol YLImageViewDelegate <NSObject>
    @optional
    - (void)gifImageView:(YLImageView*)view didShowFrameIndex:(NSUInteger)frameIdx;
    - (void)gifImageViewDidStartAnimating:(YLImageView*)view;
    - (void)gifImageViewDidStopAnimating:(YLImageView*)view;
    @end

####Usage
Super simple:

    YLGIFImage *img = (YLGIFImage*)[YLGIFImage imageNamed:@"joy.gif"];
    [myImageView setImage:img];
    myImageView.delegate = self;

Then start the animation:

    [myImageView startAnimating];

Stop the animation:

    [myImageView stopAnimating];

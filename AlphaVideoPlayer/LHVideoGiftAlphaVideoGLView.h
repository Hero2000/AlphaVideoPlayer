#import <UIKit/UIKit.h>
#import "LHVideoGiftOpenGLView.h"

@interface LHVideoGiftAlphaVideoGLView : LHVideoGiftOpenGLView

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer;
- (void)prepareForBackground;

@end

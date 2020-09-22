#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface LHVideoGiftAlphaVideoMetalView : UIView

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END

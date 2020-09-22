#import <UIKit/UIKit.h>


#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>


@interface LHVideoGiftOpenGLView : UIView
{
    // must use old-school ivars so we can pass their addresses along to OpenGL calls
    GLint framebufferWidth;
    GLint framebufferHeight;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint sampleFramebuffer;
    GLuint sampleColorRenderbuffer;
}

typedef struct OpenGlViewParameters
{
    BOOL depthBuffer;
    CGFloat resolutionScale;
} OpenGLViewParameters;

@property (nonatomic, strong) EAGLContext *context;

- (instancetype)initWithFrame:(CGRect)frame
               andEAGLContext:(EAGLContext *)context
                andParameters:(OpenGLViewParameters)params;

- (instancetype)initWithFrame:(CGRect)frame
               andEAGLContext:(EAGLContext *)context;

- (void)setFramebuffer;

- (BOOL)presentFramebuffer;

@end

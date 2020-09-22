#import "LHVideoGiftAlphaVideoMetalView.h"
#import <Metal/Metal.h>
@import simd;

//左侧两个是Metal绘制的坐标，右侧两个是 texure 坐标
//左侧坐标是完整的，右侧坐标表示只取左半部分（alpha的部分，右半部分rgba会在shader中通过偏移来取值）
float lh_cubeVertexData[16] = {
    -1.0, -1.0,  0.0, 1.0,
     1.0, -1.0,  0.5, 1.0,
    -1.0,  1.0,  0.0, 0.0,
     1.0,  1.0,  0.5, 0.0,
};

@interface LHVideoGiftAlphaVideoMetalView()

@property (nonatomic, strong) CAMetalLayer *metalLayer;
@property (nonatomic, strong) id <CAMetalDrawable> currentDrawable;
@property (nonatomic, strong) MTLRenderPassDescriptor *renderPassDescriptor;

// renderer
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLLibrary> defaultLibrary;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLTexture> textureBGRA;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;

@property (nonatomic, assign) BOOL settedup;

@end

@implementation LHVideoGiftAlphaVideoMetalView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    if (_textureCache != nil) {
        CFRelease(_textureCache);
    } else {
        NSLog(@"==========dealloc wtf %p", self);
    }
}
 
- (void)prepareMetalEnv {
    if (self.settedup) {
        return ;
    }
    self.settedup = YES;
    self.opaque = NO;
    self.backgroundColor = [UIColor clearColor];
    self.contentScaleFactor = [UIScreen mainScreen].scale;

    // Find a usable device
    _device = MTLCreateSystemDefaultDevice();
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load all the shader files with a metal file extension in the project
    _defaultLibrary = [_device newDefaultLibrary];
    
    // Setup metal layer and add as sub layer to view
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.opaque = NO; //默认是YES，一定要设置为NO，否则不会透明
    
    // Change this to NO if the compute encoder is used as the last pass on the drawable texture
    _metalLayer.framebufferOnly = YES;
    
    // Add metal layer to the views layer hierarchy
    [_metalLayer setFrame:self.layer.bounds];
    [self.layer addSublayer:_metalLayer];
    
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);
        
    // Load the fragment program into the library
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"lh_fragmentShader"];
    
    // Load the vertex program into the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"lh_vertexShader"];
    
    // Setup the vertex buffers
    _vertexBuffer = [_device newBufferWithBytes:lh_cubeVertexData length:sizeof(lh_cubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];
    _vertexBuffer.label = @"LHVideoAnimationVertices";
    
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"LHVideoAnimationPipeline";
    [pipelineStateDescriptor setSampleCount: 1];
    [pipelineStateDescriptor setVertexFunction:vertexProgram];
    [pipelineStateDescriptor setFragmentFunction:fragmentProgram];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
    pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    
    NSError* error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
        
    CGSize drawableSize = self.bounds.size;
    drawableSize.width *= self.contentScaleFactor;
    drawableSize.height *= self.contentScaleFactor;
    _metalLayer.drawableSize = drawableSize;
}

- (void)displayPixelBuffer:(CVImageBufferRef)pixelBuffer {
    [self prepareMetalEnv];
    [self generateTexture:pixelBuffer];
    CVPixelBufferRelease(pixelBuffer);

    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"ELVideoAnimationCommand";
    
    // obtain a drawable texture for this render pass and set up the renderpass descriptor for the command encoder to render into
    id <CAMetalDrawable> drawable = [_metalLayer nextDrawable];
    if (!drawable) {
        return ;
    }
    [self setupRenderPassDescriptorForTexture:drawable.texture];
    
    // Create a render command encoder so we can render into something
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    renderEncoder.label = @"ELVideoAnimationRenderEncoder";
    
    // Set context state
    if(self.textureBGRA != nil) {
        [renderEncoder pushDebugGroup:@"ELVideoAnimationRenderEncoderDebugGroup"];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [renderEncoder setFragmentTexture:_textureBGRA atIndex:0];
        
        // Tell the render context we want to draw our primitives
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
        [renderEncoder popDebugGroup];
    }
    
    // We're done encoding commands
    [renderEncoder endEncoding];
    
    // Call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
//    __block dispatch_semaphore_t block_sema = _inflight_semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
//        dispatch_semaphore_signal(block_sema);
    }];
    
    // Schedule a present once the framebuffer is complete
    [commandBuffer presentDrawable:drawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

- (void)setupRenderPassDescriptorForTexture:(id <MTLTexture>) texture
{
    if (_renderPassDescriptor == nil)
        _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    _renderPassDescriptor.colorAttachments[0].texture = texture;
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.f, 0.0f, 0.0f, 0.f);
}

- (void)generateTexture:(CVImageBufferRef)pixelBuffer {
    id<MTLTexture> textureBGRA = nil;
    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;

    CVMetalTextureRef texture = NULL;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
    if(status == kCVReturnSuccess) {
        textureBGRA = CVMetalTextureGetTexture(texture);
    }
    CFRelease(texture);
    
    // always assign the textures atomic
    self->_textureBGRA = textureBGRA;
    CVMetalTextureCacheFlush(_textureCache, 0);
}

@end

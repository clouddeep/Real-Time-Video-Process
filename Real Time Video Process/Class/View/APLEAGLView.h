/*
    Copyright (C) 2015 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This class contains an UIView backed by a CAEAGLLayer. It handles rendering input textures to the view. The object loads, compiles and links the fragment and vertex shader to be used during rendering.
 */

#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

// OpenGL ES 2.0 -> 3.0:
// 1. import ES2 -> ES3
// 2. OpenGL ES 2.0：GL_RED_EXT、GL_RG_EXT
//    OpenGL ES 3.0：GL_LUMINANCE、GL_LUMINANCE_ALPHA

@interface APLEAGLView : UIView

@property GLfloat preferredRotation;
@property CGSize presentationRect;
@property GLfloat chromaThreshold;
@property GLfloat lumaThreshold;

- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

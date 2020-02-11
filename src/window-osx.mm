/******************************************************************************
    Copyright (C) 2016-2019 by Streamlabs (General Workings Inc)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

******************************************************************************/

#include "window-osx.h"

#include <iostream>


@interface TestView: NSView
{
  NSOpenGLContext* mContext;
  GLuint mProgramID;
  GLuint mTexture;
  GLuint mTextureUniform;
  GLuint mPosAttribute;
  GLuint mVertexbuffer;
}

@end

TestView *view;

@implementation TestView

- (id)initWithFrame:(NSRect)aFrame
{
  if (self = [super initWithFrame:aFrame]) {
    NSOpenGLPixelFormatAttribute fmtAttribute;
    NSOpenGLPixelFormatAttribute attribs[] = {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        fmtAttribute
    };
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
    mContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    GLint swapInt = 1;
    [mContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    GLint opaque = 1;
    [mContext setValues:&opaque forParameter:NSOpenGLCPSurfaceOpacity];
    [mContext makeCurrentContext];
    [self _initGL];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_surfaceNeedsUpdate:)
                                                 name:NSViewGlobalFrameDidChangeNotification
                                               object:self];
  }
  return self;
}

- (void)dealloc
{
  [self _cleanupGL];
  [mContext release];
  [super dealloc];
}

static GLuint
CompileShaders(const char* vertexShader, const char* fragmentShader)
{
  // Create the shaders
  GLuint vertexShaderID = glCreateShader(GL_VERTEX_SHADER);
  GLuint fragmentShaderID = glCreateShader(GL_FRAGMENT_SHADER);

  GLint result = GL_FALSE;
  int infoLogLength;

  // Compile Vertex Shader
  glShaderSource(vertexShaderID, 1, &vertexShader , NULL);
  glCompileShader(vertexShaderID);

  // Check Vertex Shader
  glGetShaderiv(vertexShaderID, GL_COMPILE_STATUS, &result);
  glGetShaderiv(vertexShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
  if (infoLogLength > 0) {
    char* vertexShaderErrorMessage = new char[infoLogLength+1];
    glGetShaderInfoLog(vertexShaderID, infoLogLength, NULL, vertexShaderErrorMessage);
    printf("%s\n", vertexShaderErrorMessage);
    delete[] vertexShaderErrorMessage;
  }

  // Compile Fragment Shader
  glShaderSource(fragmentShaderID, 1, &fragmentShader , NULL);
  glCompileShader(fragmentShaderID);

  // Check Fragment Shader
  glGetShaderiv(fragmentShaderID, GL_COMPILE_STATUS, &result);
  glGetShaderiv(fragmentShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
  if (infoLogLength > 0) {
    char* fragmentShaderErrorMessage = new char[infoLogLength+1];
    glGetShaderInfoLog(fragmentShaderID, infoLogLength, NULL, fragmentShaderErrorMessage);
    printf("%s\n", fragmentShaderErrorMessage);
    delete[] fragmentShaderErrorMessage;
  }

  // Link the program
  GLuint programID = glCreateProgram();
  glAttachShader(programID, vertexShaderID);
  glAttachShader(programID, fragmentShaderID);
  glLinkProgram(programID);

  // Check the program
  glGetProgramiv(programID, GL_LINK_STATUS, &result);
  glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &infoLogLength);
  if (infoLogLength > 0) {
    char* programErrorMessage = new char[infoLogLength+1];
    glGetProgramInfoLog(programID, infoLogLength, NULL, programErrorMessage);
    printf("%s\n", programErrorMessage);
    delete[] programErrorMessage;
  }

  glDeleteShader(vertexShaderID);
  glDeleteShader(fragmentShaderID);

  return programID;
}

static GLuint
CreateTexture(NSSize size, void (^drawCallback)(CGContextRef ctx))
{
  int width = size.width;
  int height = size.height;
  CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
  CGContextRef imgCtx = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
                                              rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
  CGColorSpaceRelease(rgb);
  drawCallback(imgCtx);

  GLuint texture = 0;
  glActiveTexture(GL_TEXTURE0);
  glGenTextures(1, &texture);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);
  glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, CGBitmapContextGetData(imgCtx));
  glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  return texture;
}

static GLuint
CreateTextureThroughIOSurface(NSSize size, CGLContextObj cglContextObj, void (^drawCallback)(CGContextRef ctx))
{
  int width = size.width;
  int height = size.height;

  NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSNumber numberWithInt:width], kIOSurfaceWidth,
                         [NSNumber numberWithInt:height], kIOSurfaceHeight,
                         [NSNumber numberWithInt:4], kIOSurfaceBytesPerElement,
                         // [NSNumber numberWithBool:YES], kIOSurfaceIsGlobal,
                         nil];

  IOSurfaceRef surf = IOSurfaceCreate((CFDictionaryRef)dict);
  IOSurfaceLock(surf, 0, NULL);
  void* data = IOSurfaceGetBaseAddress(surf);
  size_t stride = IOSurfaceGetBytesPerRow(surf);

  CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
  CGContextRef imgCtx = CGBitmapContextCreate(data, width, height, 8, stride,
                                              rgb, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
  CGColorSpaceRelease(rgb);
  drawCallback(imgCtx);

  IOSurfaceUnlock(surf, 0, NULL);

  GLuint texture = 0;
  glActiveTexture(GL_TEXTURE0);
  glGenTextures(1, &texture);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, texture);

  CGLTexImageIOSurface2D(cglContextObj, GL_TEXTURE_RECTANGLE_ARB, GL_RGBA, width, height, 
                         GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surf, 0);
  // glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, CGBitmapContextGetData(imgCtx));

  // XXX WE ARE LEAKING 'surf' HERE.

  return texture;
}

- (void)_initGL
{  
  // Create and compile our GLSL program from the shaders.
  mProgramID = CompileShaders(
    "#version 120\n"
    "// Input vertex data, different for all executions of this shader.\n"
    "attribute vec2 aPos;\n"
    "varying vec2 vPos;\n"
    "void main(){\n"
    "  vPos = aPos;\n"
    "  gl_Position = vec4(aPos.x * 2.0 - 1.0, 1.0 - aPos.y * 2.0, 0.0, 1.0);\n"
    "}\n",

    "#version 120\n"
    "varying vec2 vPos;\n"
    "uniform sampler2DRect uSampler;\n"
    "void main()\n"
    "{\n"
    "  gl_FragColor = texture2DRect(uSampler, vPos * vec2(300, 200));\n" // <-- ATTENTION I HARDCODED THE TEXTURE SIZE HERE SORRY ABOUT THAT
    "}\n");

  // Create a texture
  mTexture = CreateTextureThroughIOSurface(NSMakeSize(300, 200), [mContext CGLContextObj], ^(CGContextRef ctx) {
    // Clear with white.
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, 300, 200));

    // Draw a bunch of circles.
    for (int i = 0; i < 30; i++) {
      CGFloat radius = 20.0f + 4.0f * i;
      CGFloat angle = i * 1.1;
      CGPoint circleCenter = { 150 + radius * cos(angle), 100 + radius * sin(angle) };
      CGFloat circleRadius = 10;
      CGContextSetRGBFillColor(ctx, 0, i % 2, 1 - (i % 2), 1); 
      CGContextFillEllipseInRect(ctx, CGRectMake(circleCenter.x - circleRadius, circleCenter.y - circleRadius, circleRadius * 2, circleRadius * 2));
    }
  });
  mTextureUniform = glGetUniformLocation(mProgramID, "uSampler");

  // Get a handle for our buffers
  mPosAttribute = glGetAttribLocation(mProgramID, "aPos");

  static const GLfloat g_vertex_buffer_data[] = { 
     0.0f,  0.0f,
     1.0f,  0.0f,
     0.0f,  1.0f,
     1.0f,  1.0f,
  };

  glGenBuffers(1, &mVertexbuffer);
  glBindBuffer(GL_ARRAY_BUFFER, mVertexbuffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(g_vertex_buffer_data), g_vertex_buffer_data, GL_STATIC_DRAW);
}

- (void)_cleanupGL
{
  glDeleteTextures(1, &mTexture);
  glDeleteBuffers(1, &mVertexbuffer);
}

- (void)_surfaceNeedsUpdate:(NSNotification*)notification
{
  [mContext update];
}

- (void)drawRect:(NSRect)aRect
{
  [mContext setView:self];
  [mContext makeCurrentContext];

  NSSize backingSize = [self convertSizeToBacking:[self bounds].size];
  GLdouble width = backingSize.width;
  GLdouble height = backingSize.height;
  glViewport(0, 0, width, height);

  glClearColor(0.0, 1.0, 0.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgram(mProgramID);

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, mTexture);
  glUniform1i(mTextureUniform, 0);

  glEnableVertexAttribArray(mPosAttribute);
  glBindBuffer(GL_ARRAY_BUFFER, mVertexbuffer);
  glVertexAttribPointer(
    mPosAttribute, // The attribute we want to configure
    2,             // size
    GL_FLOAT,      // type
    GL_FALSE,      // normalized?
    0,             // stride
    (void*)0       // array buffer offset
  );

  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // 4 indices starting at 0 -> 2 triangles

  glDisableVertexAttribArray(mPosAttribute);

  [mContext flushBuffer];
}

- (BOOL)wantsBestResolutionOpenGLSurface
{
  return YES;
}

@end

@implementation WindowImplObj

WindowObjCInt::WindowObjCInt(void)
    : self(NULL)
{   }

WindowObjCInt::~WindowObjCInt(void)
{
    [(id)self dealloc];
}

void WindowObjCInt::init(void)
{
    self = [[WindowImplObj alloc] init];
}

void WindowObjCInt::createWindow(void)
{
    NSLog(@"Creating a window inside the client");
    CGWindowListOption listOptions;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    int count = [windowList count];
    std::cout << "COUNT WINDOWS :" << count << std::endl;

    for (CFIndex idx=0; idx<CFArrayGetCount(windowList); idx++) {
        CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, idx);
        CFStringRef windowName = (CFStringRef)CFDictionaryGetValue(dict, kCGWindowName);

        NSInteger windowNumberInt = [[dict objectForKey:@"kCGWindowNumber"] integerValue];

        NSString* nsWindowName = (NSString*)windowName;
        if (nsWindowName && [nsWindowName isEqualToString:@"Streamlabs OBS"]) {
            NSLog(@"Window name: %@", nsWindowName);
            NSLog(@"Window number: %d", windowNumberInt);

            NSRect content_rect = NSMakeRect(500, 500, 1000, 500);
            NSWindow* parentWin = [NSApp windowWithWindowNumber:windowNumberInt];
            if (parentWin)
                NSLog(@"VALID WINDOW");

            NSWindow* win = [
                        [NSWindow alloc]
                        initWithContentRect:content_rect
                        styleMask:NSBorderlessWindowMask // movable
                        backing:NSBackingStoreBuffered
                        defer:NO
                    ];

            win.backgroundColor = [NSColor redColor];
            [win setOpaque:NO];
            win.alphaValue = 0.5f;
            [parentWin addChildWindow:win ordered:NSWindowAbove];

            view = [[TestView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
            [view setWantsLayer:YES];
            view.layer.backgroundColor = [[NSColor yellowColor] CGColor];

            [win.contentView addSubview:view];


            NSLog(@"subviews are %@", [win.contentView subviews]);
        }
    }

    CFRelease(windowList);
}

@end

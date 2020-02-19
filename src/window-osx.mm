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

IOSurfaceRef surface;

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

- (void) renderFrames
{
  while (1) {
    [NSThread sleepForTimeInterval:1/60];
    [self drawRect:self.frame];
  }
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
    "uniform vec2 size;\n"
    "void main()\n"
    "{\n"
    "  gl_FragColor = texture2DRect(uSampler, vPos * size);\n"
    "}\n");

  glActiveTexture(GL_TEXTURE0);
  glGenTextures(1, &mTexture);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, mTexture);

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

  NSThread* thread = [ [NSThread alloc] initWithTarget:self
                          selector:@selector( renderFrames )
                        object:nil ];

  [ thread start ];
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
  uint32_t width_surface = 1532;
  uint32_t height_surface = 490;

  void* data = IOSurfaceGetBaseAddress(surface);
  CGLTexImageIOSurface2D([mContext CGLContextObj], GL_TEXTURE_RECTANGLE_ARB, GL_RGBA, IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface), 
                         GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surface, 0);

  [mContext setView:self];
  [mContext makeCurrentContext];

  NSSize backingSize = [self convertSizeToBacking:[self bounds].size];
  GLdouble width = backingSize.width;
  GLdouble height = backingSize.height;
  glViewport(0, 0, width, height);

  glClearColor(0.0, 1.0, 0.0, 1.0);
  glClear(GL_COLOR_BUFFER_BIT);

  glUseProgram(mProgramID);

  GLuint loc_size = glGetUniformLocation(mProgramID, "size");
  glUniform2f(loc_size, (GLfloat)IOSurfaceGetWidth(surface), (GLfloat)IOSurfaceGetHeight(surface));

  glActiveTexture(GL_TEXTURE0);
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, mTexture);

  glBegin(GL_QUADS);
  glTexCoord2f(0.0, 0.0);
  glVertex3f(-1.0, -1.0, 0.0);
  glTexCoord2f(1.0, 0.0);
  glVertex3f(1.0, -1.0, 0.0);
  glTexCoord2f(1.0, 1.0);
  glVertex3f(1.0, 1.0, 0.0);
  glTexCoord2f(0.0, 1.0);
  glVertex3f(-1.0, 1.0, 0.0);
  glEnd();

	if (surface) {
		GLint		saveMatrixMode;
		glDisable(GL_TEXTURE_RECTANGLE_ARB);
		glGetIntegerv(GL_MATRIX_MODE, &saveMatrixMode);
		glMatrixMode(GL_TEXTURE);
		glPopMatrix();
		glMatrixMode(saveMatrixMode);
	}

  [mContext flushBuffer];

  IOSurfaceDecrementUseCount(surface);
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

void WindowObjCInt::createWindow(uint32_t surfaceID)
{
    surface = IOSurfaceLookup((IOSurfaceID) surfaceID);
    GLsizei _texWidth	= IOSurfaceGetWidth(surface);
    GLsizei _texHeight	= IOSurfaceGetHeight(surface);

    if (!surface) {
        NSLog(@"INVALID IOSurface");
        return;
    }

    CGWindowListOption listOptions;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
    int count = [windowList count];

    for (CFIndex idx=0; idx<CFArrayGetCount(windowList); idx++) {
        CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, idx);
        CFStringRef windowName = (CFStringRef)CFDictionaryGetValue(dict, kCGWindowName);

        NSInteger windowNumberInt = [[dict objectForKey:@"kCGWindowNumber"] integerValue];

        NSString* nsWindowName = (NSString*)windowName;
        if (nsWindowName && [nsWindowName isEqualToString:@"Streamlabs OBS"]) {
            NSRect content_rect = NSMakeRect(0, 500, 1532, 490);
            NSWindow* parentWin = [NSApp windowWithWindowNumber:windowNumberInt];

            NSWindow* win = [
                        [NSWindow alloc]
                        initWithContentRect:content_rect
                        styleMask:NSBorderlessWindowMask // movable
                        backing:NSBackingStoreBuffered
                        defer:NO
                    ];

            win.backgroundColor = [NSColor redColor];
            [win setOpaque:YES];
            [parentWin addChildWindow:win ordered:NSWindowAbove];

            view = [[TestView alloc] initWithFrame:NSMakeRect(0, 0, 1532, 490)];
            [view setWantsLayer:YES];
            view.layer.backgroundColor = [[NSColor yellowColor] CGColor];
            [win.contentView addSubview:view];
        }
    }

    CFRelease(windowList);
}

@end

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
#include <thread>

IOSurfaceRef surface = NULL;
bool stop = false;
std::thread* thread;

NSOpenGLContext* mContext;
GLuint mProgramID;
GLuint mTexture;
GLuint mTextureUniform;
GLuint mPosAttribute;
GLuint mVertexbuffer;

@interface TestView: NSView
{
}

@end

TestView *view;

void renderFrames()
{
  while (!stop) {
    std::this_thread::sleep_for(std::chrono::milliseconds(16));
    dispatch_sync(dispatch_get_main_queue(), ^{
      if (!stop) {
        view.needsDisplay = YES;
      }
    });
  }
}

static const char *gl_error_to_str(GLenum errorcode)
{
	static const struct {
		GLenum error;
		const char *str;
	} err_to_str[] = {
		{
			GL_INVALID_ENUM,
			"GL_INVALID_ENUM",
		},
		{
			GL_INVALID_VALUE,
			"GL_INVALID_VALUE",
		},
		{
			GL_INVALID_OPERATION,
			"GL_INVALID_OPERATION",
		},
		{
			GL_INVALID_FRAMEBUFFER_OPERATION,
			"GL_INVALID_FRAMEBUFFER_OPERATION",
		},
		{
			GL_OUT_OF_MEMORY,
			"GL_OUT_OF_MEMORY",
		},
		{
			GL_STACK_UNDERFLOW,
			"GL_STACK_UNDERFLOW",
		},
		{
			GL_STACK_OVERFLOW,
			"GL_STACK_OVERFLOW",
		},
	};
	for (size_t i = 0; i < sizeof(err_to_str) / sizeof(*err_to_str); i++) {
		if (err_to_str[i].error == errorcode)
			return err_to_str[i].str;
	}
	return "Unknown";
}

static inline bool gl_success(const char *funcname)
{
	GLenum errorcode = glGetError();
	if (errorcode != GL_NO_ERROR) {
		int attempts = 8;
		do {
      std::cout << funcname << " failed, glGetError returned " << gl_error_to_str(errorcode) << ", " << errorcode << std::endl;
			errorcode = glGetError();

			--attempts;
			if (attempts == 0) {
        std::cout << "Too many GL errors, moving on" << std::endl;
				break;
			}
		} while (errorcode != GL_NO_ERROR);
		return false;
	}

	return true;
}

@implementation TestView

- (id)initWithFrame:(NSRect)aFrame
{
  if (self = [super initWithFrame:aFrame]) {
    NSOpenGLPixelFormatAttribute glAttributes[] =
    {
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        0
    };
    mContext = [[NSOpenGLContext alloc] initWithFormat:[[NSOpenGLPixelFormat alloc] initWithAttributes:glAttributes]
                                                shareContext:nil];
    GLint swapInt = 1;
    [mContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    GLint opaque = 1;
    [mContext setValues:&opaque forParameter:NSOpenGLCPSurfaceOpacity];
    [mContext makeCurrentContext];
    [self _initGL];
  }
  return self;
}

- (void)dealloc
{
  [self _cleanupGL];
  [NSOpenGLContext clearCurrentContext];
  [mContext release];
  [super dealloc];
}

static GLuint
CompileShaders(const char* vertexShader, const char* fragmentShader)
{
  // Create the shaders
  GLuint vertexShaderID = glCreateShader(GL_VERTEX_SHADER);
  gl_success("glCreateShader");
  GLuint fragmentShaderID = glCreateShader(GL_FRAGMENT_SHADER);
  gl_success("glCreateShader");

  GLint result = GL_FALSE;
  int infoLogLength;

  // Compile Vertex Shader
  glShaderSource(vertexShaderID, 1, &vertexShader , NULL);
  gl_success("glShaderSource");
  glCompileShader(vertexShaderID);
  gl_success("glCompileShader");

  // Check Vertex Shader
  glGetShaderiv(vertexShaderID, GL_COMPILE_STATUS, &result);
  gl_success("glGetShaderiv");
  glGetShaderiv(vertexShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
  gl_success("glGetShaderiv");
  if (infoLogLength > 0) {
    char* vertexShaderErrorMessage = new char[infoLogLength+1];
    glGetShaderInfoLog(vertexShaderID, infoLogLength, NULL, vertexShaderErrorMessage);
    printf("%s\n", vertexShaderErrorMessage);
    delete[] vertexShaderErrorMessage;
  }

  // Compile Fragment Shader
  glShaderSource(fragmentShaderID, 1, &fragmentShader , NULL);
  gl_success("glShaderSource");
  glCompileShader(fragmentShaderID);
  gl_success("glCompileShader");

  // Check Fragment Shader
  glGetShaderiv(fragmentShaderID, GL_COMPILE_STATUS, &result);
  gl_success("glGetShaderiv");
  glGetShaderiv(fragmentShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
  gl_success("glGetShaderiv");
  if (infoLogLength > 0) {
    std::cout << "Error glGetProgramiv fragmentShaderID" << std::endl;
    char* fragmentShaderErrorMessage = new char[infoLogLength+1];
    glGetShaderInfoLog(fragmentShaderID, infoLogLength, NULL, fragmentShaderErrorMessage);
    printf("%s\n", fragmentShaderErrorMessage);
    delete[] fragmentShaderErrorMessage;
  }

  // Link the program
  GLuint programID = glCreateProgram();
  gl_success("glCreateProgram");
  glAttachShader(programID, vertexShaderID);
  gl_success("glAttachShader");
  glAttachShader(programID, fragmentShaderID);
  gl_success("glAttachShader");
  glLinkProgram(programID);
  gl_success("glLinkProgram");

  // Check the program
  glGetProgramiv(programID, GL_LINK_STATUS, &result);
  gl_success("glGetProgramiv");
  glGetProgramiv(programID, GL_INFO_LOG_LENGTH, &infoLogLength);
  gl_success("glGetProgramiv");
  if (infoLogLength > 0) {
    std::cout << "Error glGetProgramiv programID" << std::endl;
    char* programErrorMessage = new char[infoLogLength+1];
    glGetProgramInfoLog(programID, infoLogLength, NULL, programErrorMessage);
    printf("%s\n", programErrorMessage);
    delete[] programErrorMessage;
  }

  glDeleteShader(vertexShaderID);
  gl_success("glDeleteShader");
  glDeleteShader(fragmentShaderID);
  gl_success("glDeleteShader");

  return programID;
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
  gl_success("glActiveTexture");
  glGenTextures(1, &mTexture);
  gl_success("glGenTextures");
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, mTexture);
  gl_success("glBindTexture");

  mTextureUniform = glGetUniformLocation(mProgramID, "uSampler");
  gl_success("glGetUniformLocation");

  // Get a handle for our buffers
  mPosAttribute = glGetAttribLocation(mProgramID, "aPos");
  gl_success("glGetAttribLocation");

  static const GLfloat g_vertex_buffer_data[] = { 
     0.0f,  0.0f,
     1.0f,  0.0f,
     0.0f,  1.0f,
     1.0f,  1.0f,
  };

  glGenBuffers(1, &mVertexbuffer);
  gl_success("glGenBuffers");
  glBindBuffer(GL_ARRAY_BUFFER, mVertexbuffer);
  gl_success("glBindBuffer");
  glBufferData(GL_ARRAY_BUFFER, sizeof(g_vertex_buffer_data), g_vertex_buffer_data, GL_STATIC_DRAW);
  gl_success("glBufferData");
}

- (void)_cleanupGL
{
  glDeleteTextures(1, &mTexture);
  glDeleteBuffers(1, &mVertexbuffer);
  glDeleteProgram(mProgramID);
}

- (void)_surfaceNeedsUpdate:(NSNotification*)notification
{
  NSLog(@"_surfaceNeedsUpdate");
  [mContext update];
}

- (void)drawRect:(NSRect)aRect
{
  if (!surface)
    return;

  CGLTexImageIOSurface2D([mContext CGLContextObj], GL_TEXTURE_RECTANGLE_ARB, GL_RGBA, IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface),
                        GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surface, 0);
  gl_success("CGLTexImageIOSurface2D");

  [mContext setView:self];
  [mContext makeCurrentContext];

  NSSize backingSize = [self convertSizeToBacking:[self bounds].size];
  GLdouble width = backingSize.width;
  GLdouble height = backingSize.height;
  glViewport(0, 0, width, height);

  gl_success("glViewport");

  glClearColor(0.0, 1.0, 0.0, 1.0);
  gl_success("glClearColor");
  glClear(GL_COLOR_BUFFER_BIT);
  gl_success("glClear");

  glUseProgram(mProgramID);
  gl_success("glUseProgram");

  GLuint loc_size = glGetUniformLocation(mProgramID, "size");
  gl_success("glGetUniformLocation");
  glUniform2f(loc_size, (GLfloat)IOSurfaceGetWidth(surface), (GLfloat)IOSurfaceGetHeight(surface));
  gl_success("glUniform2f");

  glActiveTexture(GL_TEXTURE0);
  gl_success("glActiveTexture");
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, mTexture);
  gl_success("glBindTexture");

  glUniform1i(mTextureUniform, 0);
  gl_success("glUniform1i");

  glEnableVertexAttribArray(mPosAttribute);
  gl_success("glEnableVertexAttribArray");
  glBindBuffer(GL_ARRAY_BUFFER, mVertexbuffer);
  gl_success("glBindBuffer");
  glVertexAttribPointer(
    mPosAttribute, // The attribute we want to configure
    2,             // size
    GL_FLOAT,      // type
    GL_FALSE,      // normalized?
    0,             // stride
    (void*)0       // array buffer offset
  );
  gl_success("glVertexAttribPointer");

  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4); // 4 indices starting at 0 -> 2 triangles
  gl_success("glDrawArrays");

  glDisableVertexAttribArray(mPosAttribute);
  gl_success("glDisableVertexAttribArray");

  [mContext flushBuffer];
}

- (BOOL)wantsBestResolutionOpenGLSurface
{
  return YES;
}

- (NSView *)hitTest:(NSPoint)aPoint
{
    // pass-through events that don't hit one of the visible subviews
    for (NSView *subView in [self subviews]) {
        if (![subView isHidden] && [subView hitTest:aPoint])
            return subView;
    }

    return nil;
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

void WindowObjCInt::createWindow()
{
  CGWindowListOption listOptions;
  CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll, kCGNullWindowID);
  int count = [windowList count];

  for (CFIndex idx=0; idx<CFArrayGetCount(windowList); idx++) {
      CFDictionaryRef dict = (CFDictionaryRef)CFArrayGetValueAtIndex(windowList, idx);
      CFStringRef windowName = (CFStringRef)CFDictionaryGetValue(dict, kCGWindowName);

      NSInteger windowNumberInt = [[dict objectForKey:@"kCGWindowNumber"] integerValue];

      NSString* nsWindowName = (NSString*)windowName;
      if (nsWindowName && [nsWindowName isEqualToString:@"Streamlabs OBS"]) {
          NSWindow* parentWin = [NSApp windowWithWindowNumber:windowNumberInt];
          view = [[TestView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
          [parentWin.contentView addSubview:view];
      }
  }

  CFRelease(windowList);
}

void WindowObjCInt::destroyWindow(void)
{
  stop = true;
  [view removeFromSuperview];
  CFRelease(view);
}

void WindowObjCInt::connectIOSurfaceJS(uint32_t surfaceID)
{
  surface = IOSurfaceLookup((IOSurfaceID) surfaceID);

  if (!surface)
    return;

  stop = false;
  thread = new std::thread(renderFrames);

  [view setFrameSize:NSMakeSize(IOSurfaceGetWidth(surface), IOSurfaceGetHeight(surface))];
}

void WindowObjCInt::destroyIOSurface(void)
{
  if (surface) {
    CFRelease(surface);
    surface = NULL;
  }
}

void WindowObjCInt::moveWindow(uint32_t cx, uint32_t cy)
{
  std::cout << "NWR: coordinates: " << cx << ":" << cy << std::endl;
  [view setFrameOrigin:NSMakePoint(cx, cy)];
}

@end

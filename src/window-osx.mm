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

NSOperatingSystemVersion OSversion = [NSProcessInfo processInfo].operatingSystemVersion;

void renderFrames(WindowInfo* wi)
{
  while (!wi->view.glData->stop) {
    std::this_thread::sleep_for(std::chrono::milliseconds(16));

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!wi->destroyed && !wi->view.glData->stop) {
        wi->view.needsDisplay = YES;
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

@implementation OpenGLView
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
    self.glData = new OpenGLData();
    self.glData->mContext = [[NSOpenGLContext alloc] initWithFormat:[[NSOpenGLPixelFormat alloc] initWithAttributes:glAttributes]
                                                shareContext:nil];
    GLint swapInt = 1;
    [self.glData->mContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    GLint opaque = 1;
    [self.glData->mContext setValues:&opaque forParameter:NSOpenGLCPSurfaceOpacity];
    [self.glData->mContext makeCurrentContext];
    [self _initGL];
  }
  return self;
}

- (void)dealloc
{
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
  self.glData->mProgramID = CompileShaders(
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
  glGenTextures(1, &self.glData->mTexture);
  gl_success("glGenTextures");
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, self.glData->mTexture);
  gl_success("glBindTexture");

  self.glData->mTextureUniform =
    glGetUniformLocation(self.glData->mProgramID, "uSampler");
  gl_success("glGetUniformLocation");

  // Get a handle for our buffers
  self.glData->mPosAttribute =
    glGetAttribLocation(self.glData->mProgramID, "aPos");
  gl_success("glGetAttribLocation");

  static const GLfloat g_vertex_buffer_data[] = { 
     0.0f,  0.0f,
     1.0f,  0.0f,
     0.0f,  1.0f,
     1.0f,  1.0f,
  };

  glGenBuffers(1, &self.glData->mVertexbuffer);
  gl_success("glGenBuffers");
  glBindBuffer(GL_ARRAY_BUFFER, self.glData->mVertexbuffer);
  gl_success("glBindBuffer");
  glBufferData(GL_ARRAY_BUFFER,
              sizeof(g_vertex_buffer_data),
              g_vertex_buffer_data, GL_STATIC_DRAW);
  gl_success("glBufferData");
}

- (void)_cleanupGL
{
  glDeleteTextures(1, &self.glData->mTexture);
  glDeleteBuffers(1, &self.glData->mVertexbuffer);
  glDeleteProgram(self.glData->mProgramID);
}

- (void)_surfaceNeedsUpdate:(NSNotification*)notification
{
  [self.glData->mContext update];
}

- (void)drawRect:(NSRect)aRect
{
  if (!self.glData->surface || self.glData->stop)
    return;

  self.glData->mtx.lock();

  CGLTexImageIOSurface2D([self.glData->mContext CGLContextObj],
                        GL_TEXTURE_RECTANGLE_ARB, GL_RGBA,
                        IOSurfaceGetWidth(self.glData->surface),
                        IOSurfaceGetHeight(self.glData->surface),
                        GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV,
                        self.glData->surface,
                        0);
  gl_success("CGLTexImageIOSurface2D");

  [self.glData->mContext setView:self];
  [self.glData->mContext makeCurrentContext];

  NSSize backingSize = [self convertSizeToBacking:[self bounds].size];
  GLdouble width = backingSize.width;
  GLdouble height = backingSize.height;
  glViewport(0, 0, width, height);

  gl_success("glViewport");

  glClearColor(0.0, 1.0, 0.0, 1.0);
  gl_success("glClearColor");
  glClear(GL_COLOR_BUFFER_BIT);
  gl_success("glClear");

  glUseProgram(self.glData->mProgramID);
  gl_success("glUseProgram");

  GLuint loc_size = glGetUniformLocation(self.glData->mProgramID, "size");
  gl_success("glGetUniformLocation");
  glUniform2f(loc_size,
            (GLfloat)IOSurfaceGetWidth(self.glData->surface),
            (GLfloat)IOSurfaceGetHeight(self.glData->surface));
  gl_success("glUniform2f");

  glActiveTexture(GL_TEXTURE0);
  gl_success("glActiveTexture");
  glBindTexture(GL_TEXTURE_RECTANGLE_ARB, self.glData->mTexture);
  gl_success("glBindTexture");

  glUniform1i(self.glData->mTextureUniform, 0);
  gl_success("glUniform1i");

  glEnableVertexAttribArray(self.glData->mPosAttribute);
  gl_success("glEnableVertexAttribArray");
  glBindBuffer(GL_ARRAY_BUFFER, self.glData->mVertexbuffer);
  gl_success("glBindBuffer");
  glVertexAttribPointer(
    self.glData->mPosAttribute,
    2,
    GL_FLOAT,
    GL_FALSE,
    0,
    (void*)0
  );
  gl_success("glVertexAttribPointer");

  glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
  gl_success("glDrawArrays");

  glDisableVertexAttribArray(self.glData->mPosAttribute);
  gl_success("glDisableVertexAttribArray");

  [self.glData->mContext flushBuffer];
  self.glData->mtx.unlock();
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

void WindowObjCInt::createWindow(std::string name, unsigned char* handle)
{
  WindowInfo* wi = new WindowInfo();

  NSView *viewParent = *reinterpret_cast<NSView**>(handle);
  NSWindow *winParent = [viewParent window];

  wi->view = [[OpenGLView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];

  if (OSversion.majorVersion == 10 && OSversion.minorVersion < 14) {
    // Less performant but solves flickering issue on macOS High Sierra and lower
    NSRect content_rect = NSMakeRect(0, 0, 0, 0);
    wi->window = [
                [NSWindow alloc]
                initWithContentRect:content_rect
                styleMask:NSBorderlessWindowMask
                backing:NSBackingStoreBuffered
                defer:NO
            ];
    [winParent addChildWindow:wi->window ordered:NSWindowAbove];
    wi->window.ignoresMouseEvents = true;
    [wi->window.contentView addSubview:wi->view];
  } else {
    [winParent.contentView addSubview:wi->view];
  }
  windows.emplace(name, wi);
}

void WindowObjCInt::destroyWindow(std::string name)
{
  auto it = windows.find(name);
  if (it == windows.end())
    return;

  WindowInfo* wi = reinterpret_cast<WindowInfo*>(it->second);
  if (!wi->view.glData->surface)
    return;

  wi->view.glData->mtx.lock();
  wi->view.glData->stop = true;

  if (wi->view.glData->thread->joinable())
    wi->view.glData->thread->join();

  [self _cleanupGL];
  [NSOpenGLContext clearCurrentContext];
  [wi->view.glData->mContext release];
  wi->destroyed = true;
  wi->view.glData->mtx.unlock();

  [wi->view removeFromSuperview];
  CFRelease(wi->view);

  if (wi->window)
    [wi->window close];

  windows.erase(name);
}

void WindowObjCInt::connectIOSurfaceJS(std::string name, uint32_t surfaceID)
{
  auto it = windows.find(name);
  if (it == windows.end())
    return;

  WindowInfo* wi = reinterpret_cast<WindowInfo*>(it->second);
  wi->view.glData->surface = IOSurfaceLookup((IOSurfaceID) surfaceID);

  if (!wi->view.glData->surface)
    return;

  wi->view.glData->stop = false;
  wi->view.glData->thread = new std::thread(renderFrames, wi);
}

void WindowObjCInt::destroyIOSurface(std::string name)
{
  auto it = windows.find(name);
  if (it == windows.end())
    return;

  WindowInfo* wi = reinterpret_cast<WindowInfo*>(it->second);
  if (wi->view.glData->surface) {
    CFRelease(wi->view.glData->surface);
    wi->view.glData->surface = NULL;
  }
}

void WindowObjCInt::moveWindow(std::string name, uint32_t cx, uint32_t cy)
{
  auto it = windows.find(name);
  if (it == windows.end())
    return;

  WindowInfo* wi = reinterpret_cast<WindowInfo*>(it->second);

  if (OSversion.majorVersion == 10 && OSversion.minorVersion < 14) {
    NSWindow* parent = (NSWindow*)[wi->window parentWindow];
    NSRect parentFrame = [parent frame];

    NSRect frame = [wi->window frame];
    frame.size = NSMakeSize(
      IOSurfaceGetWidth(wi->view.glData->surface),
      IOSurfaceGetHeight(wi->view.glData->surface)
    );

    frame.origin.x = parentFrame.origin.x + cx;
    frame.origin.y = parentFrame.origin.y + cy;

    [wi->view setFrameSize:NSMakeSize(IOSurfaceGetWidth(wi->view.glData->surface),
                                    IOSurfaceGetHeight(wi->view.glData->surface))];

    [wi->window setFrame:frame display: YES animate: NO];
  } else {
    [wi->view setFrameSize:NSMakeSize(IOSurfaceGetWidth(wi->view.glData->surface),
                                    IOSurfaceGetHeight(wi->view.glData->surface))];
    [wi->view setFrameOrigin:NSMakePoint(cx, cy)];
  }
}

@end

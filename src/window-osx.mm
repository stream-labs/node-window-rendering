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

int screenID = 0;
NSScreen *screen;
NSRect frame;
bool hide_cursor = true;
CGDisplayStreamRef disp;
IOSurfaceRef current, prev;
pthread_mutex_t mutex;
GLuint			_surfaceTexture;

void update_display_stream(CGDisplayStreamFrameStatus status,
					 uint64_t display_time,
					 IOSurfaceRef frame_surface,
					 CGDisplayStreamUpdateRef update_ref)
{
    NSLog(@"Update display");

    if (status == kCGDisplayStreamFrameStatusStopped) {
		// os_event_signal(dc->disp_finished);
		return;
	}

	IOSurfaceRef prev_current = NULL;

	if (frame_surface && !pthread_mutex_lock(&mutex)) {
        NSLog(@"Valid frame");
		prev_current = current;
		current = frame_surface;
		CFRetain(current);
		IOSurfaceIncrementUseCount(current);

        // [view drawRect:view.frame];
		pthread_mutex_unlock(&mutex);
	} else {
        NSLog(@"Invalid frame");
    }

	if (prev_current) {
		IOSurfaceDecrementUseCount(prev_current);
		CFRelease(prev_current);
	}
}

void init_display_stream(void) {
	screen = [[NSScreen screens][screenID] retain];

	frame = [screen convertRectToBacking:screen.frame];

	NSNumber *screen_num = screen.deviceDescription[@"NSScreenNumber"];
	CGDirectDisplayID disp_id = (CGDirectDisplayID)(size_t)screen_num.pointerValue;

	NSDictionary *rect_dict =
		CFBridgingRelease(CGRectCreateDictionaryRepresentation(
			CGRectMake(0, 0, screen.frame.size.width,
				   screen.frame.size.height)));

	CFBooleanRef show_cursor_cf = hide_cursor ? kCFBooleanFalse
						      : kCFBooleanTrue;

	NSDictionary *dict = @{
		(__bridge NSString *)kCGDisplayStreamSourceRect: rect_dict,
		(__bridge NSString *)kCGDisplayStreamQueueDepth: @5,
		(__bridge NSString *)
		kCGDisplayStreamShowCursor: (id)show_cursor_cf,
	};

    const CGSize *size = &frame.size;
	disp = CGDisplayStreamCreateWithDispatchQueue(
		disp_id, size->width, size->height, 'BGRA',
		(__bridge CFDictionaryRef)dict,
		dispatch_queue_create(NULL, NULL),
		^(CGDisplayStreamFrameStatus status, uint64_t displayTime,
		  IOSurfaceRef frameSurface,
		  CGDisplayStreamUpdateRef updateRef) {
			update_display_stream(status, displayTime,
					      frameSurface, updateRef);
		});

    bool started = !CGDisplayStreamStart(disp);

    if(started)
        NSLog(@"Stream started");
    else
        NSLog(@"Stream didn't started");
}

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

            view = [[MyOpenGLView alloc] initWithFrame:NSMakeRect(100, 100, 100, 100)];
            [view setWantsLayer:YES];
            view.layer.backgroundColor = [[NSColor yellowColor] CGColor];

            [win.contentView addSubview:view];

            NSRect frame = NSMakeRect(10, 40, 90, 40);
            NSButton* pushButton = [[NSButton alloc] initWithFrame: frame]; 
            pushButton.bezelStyle = NSRoundedBezelStyle;

            [win.contentView addSubview:pushButton];

            NSLog(@"subviews are %@", [win.contentView subviews]);
            pthread_mutex_init(&mutex, NULL);

            init_display_stream();
        }
    }

    CFRelease(windowList);
}

@end

@implementation MyOpenGLView

- (NSOpenGLPixelFormat*) basicPixelFormat
{
    NSOpenGLPixelFormatAttribute	mAttrs []	= {
		NSOpenGLPFAWindow,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAColorSize,		(NSOpenGLPixelFormatAttribute)32,
		NSOpenGLPFAAlphaSize,		(NSOpenGLPixelFormatAttribute)8,
		NSOpenGLPFADepthSize,		(NSOpenGLPixelFormatAttribute)24,
		(NSOpenGLPixelFormatAttribute) 0
	};
	
	return [[[NSOpenGLPixelFormat alloc] initWithAttributes: mAttrs] autorelease];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame: frameRect pixelFormat: [self basicPixelFormat]]) {
        NSLog(@"INIT VIEW");
		CGLContextObj   cgl_ctx			= [[self openGLContext]  CGLContextObj];
		long			swapInterval	= 1;
		
		[[self openGLContext] setValues:(GLint*)(&swapInterval)
						   forParameter: NSOpenGLCPSwapInterval];
		glEnable(GL_TEXTURE_RECTANGLE_ARB);
		glGenTextures(1, &_surfaceTexture);
		glDisable(GL_TEXTURE_RECTANGLE_ARB);
	}
	
	return self;
}

- (void)drawRect:(NSRect)rect
{
    // // Enable the rectangle texture extenstion
    // glEnable(GL_TEXTURE_RECTANGLE_EXT);

    // // 1. Create a texture from the IOSurface
    // GLuint name;
    // {
    //   CGLContextObj cgl_ctx = [[self openGLContext]  CGLContextObj];

    //   glGenTextures(1, &name);
    //   GLsizei surface_w = (GLsizei)IOSurfaceGetWidth(current);
    //   GLsizei surface_h = (GLsizei)IOSurfaceGetHeight(current);

    //   glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);

    //   CGLError cglError =
    //   CGLTexImageIOSurface2D(cgl_ctx, GL_TEXTURE_RECTANGLE_EXT, GL_RGBA, surface_w, surface_h, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, current, 0);

    //   glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);          
    // }

    // // 2. Draw the texture to the current OpenGL context
    // {
    //   glBindTexture(GL_TEXTURE_RECTANGLE_EXT, name);
    //   glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    //   glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    //   glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

    //   glBegin(GL_QUADS);

    //   glColor4f(0.f, 0.f, 1.0f, 1.0f);
    // //   glTexCoord2f(   (float)NSMinX(fromRect),    (float)(NSMinY(fromRect)));
    // //   glVertex2f(     (float)NSMinX(inRect),      (float)(NSMinY(inRect)));

    // //   glTexCoord2f(   (float)NSMaxX(fromRect),    (float)NSMinY(fromRect));
    // //   glVertex2f(     (float)NSMaxX(inRect),      (float)NSMinY(inRect));

    // //   glTexCoord2f(   (float)NSMaxX(fromRect),    (float)NSMaxY(fromRect));
    // //   glVertex2f(     (float)NSMaxX(inRect),      (float)NSMaxY(inRect));

    // //   glTexCoord2f(   (float)NSMinX(fromRect),    (float)NSMaxY(fromRect));
    // //   glVertex2f(     (float)NSMinX(inRect),      (float)NSMaxY(inRect));

    //   glEnd();

    //   glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
    // }
    // glDeleteTextures(1, &name);
}

@end

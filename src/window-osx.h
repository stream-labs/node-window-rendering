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

#import "Foundation/Foundation.h"
#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#import <OpenGL/CGLIOSurface.h>
#import <GLKit/GLKit.h>
#import <OpenGL/gl.h>

#include "window-osx-obj-c-int.h"
#include "window-osx-int.hpp"

#include <map>
#include <iostream>
#include <thread>
#include <mutex>
#include <string>

@interface WindowImplObj : NSObject
@end

struct OpenGLData {
    NSOpenGLContext* mContext;
    GLuint mProgramID;
    GLuint mTexture;
    GLuint mTextureUniform;
    GLuint mPosAttribute;
    GLuint mVertexbuffer;
    IOSurfaceRef surface = NULL;
    std::thread* thread;
    std::mutex mtx;
    bool stop = false;
};

@interface OpenGLView: NSView
@property (atomic) OpenGLData* glData;
@end

struct WindowInfo {
    OpenGLView* view;
    NSWindow* window;
    bool destroyed = false;
};

std::map<std::string, void*> windows; // <std::string name, WindowInfo* wi>

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

#include <node.h>
#include <nan.h>

#include "window-osx-int.hpp"
#include <iostream>

using namespace Nan;
using namespace v8;
using namespace std;

WindowInt *window;

void createWindowJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    v8::Local<v8::Object> bufferObj = args[0].As<v8::Object>(); 
	unsigned char* handle = (unsigned char*)node::Buffer::Data(bufferObj);

    window = new WindowInt();
    window->init();
    window->createWindow(handle);
}

void destroyWindowJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    window->destroyWindow();
    delete window;
}

void connectIOSurfaceJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    v8::Local<v8::Uint32> surfaceID = v8::Local<v8::Uint32>::Cast(args[0]);

    window->connectIOSurfaceJS(surfaceID->Uint32Value());
}

void destroyIOSurfaceJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    window->destroyIOSurface();
}

void moveWindowJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    v8::Local<v8::Uint32> cx = v8::Local<v8::Uint32>::Cast(args[0]);
    v8::Local<v8::Uint32> cy = v8::Local<v8::Uint32>::Cast(args[1]);

    window->moveWindow(cx->Uint32Value(), cy->Uint32Value());
}

void init(v8::Local<v8::Object> exports) {
    /// Functions ///
    NODE_SET_METHOD(exports, "createWindow", createWindowJS);
    NODE_SET_METHOD(exports, "destroyWindow", destroyWindowJS);
    NODE_SET_METHOD(exports, "connectIOSurface", connectIOSurfaceJS);
    NODE_SET_METHOD(exports, "destroyIOSurface", destroyIOSurfaceJS);
    NODE_SET_METHOD(exports, "moveWindow", moveWindowJS);
}

NODE_MODULE(windowRendering, init)

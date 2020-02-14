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
#include "window-osx-int.hpp"
#include <iostream>

using namespace v8;

void createWindowJS(const v8::FunctionCallbackInfo<v8::Value>& args)
{
    std::cout << "Create Window JS" << std::endl;
    v8::Local<v8::Uint32> binds = v8::Local<v8::Uint32>::Cast(args[0]);
    uint32_t surfaceID = binds->Uint32Value();
    std::cout << "IOSurfaceID: " << surfaceID  << std::endl;

    WindowInt *window = new WindowInt();
    window->init();
    window->createWindow(surfaceID);
}

void init(Local<Object> exports) {
    /// Functions ///
    NODE_SET_METHOD(exports, "createWindow", createWindowJS);
}

NODE_MODULE(uiohookModule, init)
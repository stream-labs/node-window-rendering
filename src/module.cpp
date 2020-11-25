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

#include <napi.h>

#include "window.h"
#include <iostream>

Napi::Value createWindowJS(const Napi::CallbackInfo& info)
{
    std::string name = info[0].ToString().Utf8Value();
    Napi::Buffer<void *> bufferData = info[1].As<Napi::Buffer<void*>>();

    createWindow(name, bufferData.Data());
    return info.Env().Undefined();
}

Napi::Value destroyWindowJS(const Napi::CallbackInfo& info)
{
    std::string name = info[0].ToString().Utf8Value();

    destroyWindow(name);
    return info.Env().Undefined();
}

Napi::Value connectSharedMemoryJS(const Napi::CallbackInfo& info)
{
    std::string name = info[0].ToString().Utf8Value();
    uint32_t surfaceID = info[1].ToNumber().Uint32Value();

    connectSharedMemory(name, surfaceID);
    return info.Env().Undefined();
}

Napi::Value destroySharedMemoryJS(const Napi::CallbackInfo& info)
{
    std::string name = info[0].ToString().Utf8Value();

    destroySharedMemory(name);
    return info.Env().Undefined();
}

Napi::Value moveWindowJS(const Napi::CallbackInfo& info)
{
    std::string name = info[0].ToString().Utf8Value();
    uint32_t cx = info[1].ToNumber().Uint32Value();
    uint32_t cy = info[2].ToNumber().Uint32Value();

    moveWindow(name, cx, cy);
    return info.Env().Undefined();
}

void Init(Napi::Env env, Napi::Object exports) {
    exports.Set(
        Napi::String::New(env, "createWindow"),
        Napi::Function::New(env, createWindowJS));
    exports.Set(
        Napi::String::New(env, "destroyWindow"),
        Napi::Function::New(env, destroyWindowJS));
    exports.Set(
        Napi::String::New(env, "connectIOSurface"),
        Napi::Function::New(env, connectSharedMemoryJS));
    exports.Set(
        Napi::String::New(env, "destroyIOSurface"),
        Napi::Function::New(env, destroySharedMemoryJS));
    exports.Set(
        Napi::String::New(env, "moveWindow"),
        Napi::Function::New(env, moveWindowJS));
}

Napi::Object main_node(Napi::Env env, Napi::Object exports) {
    Init(env, exports);
    return exports;
}

NODE_API_MODULE(windowRendering, main_node)

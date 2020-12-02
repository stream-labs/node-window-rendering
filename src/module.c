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
#include <assert.h>
#include <node_api.h>

#include "window-rendering.h"

// Napi::Value createWindowJS(const Napi::CallbackInfo& info)
// {
//     // std::string name = info[0].ToString().Utf8Value();
//     // Napi::Buffer<void *> bufferData = info[1].As<Napi::Buffer<void*>>();

//     // createWindow(name, bufferData.Data());
//     createWindow("", nullptr);
//     return info.Env().Undefined();
// }

// Napi::Value destroyWindowJS(const Napi::CallbackInfo& info)
// {
//     const char* name = info[0].ToString().Utf8Value().c_str();

//     destroyWindow(name);
//     return info.Env().Undefined();
// }

// Napi::Value connectSharedMemoryJS(const Napi::CallbackInfo& info)
// {
//     const char* name = info[0].ToString().Utf8Value().c_str();
//     uint32_t surfaceID = info[1].ToNumber().Uint32Value();

//     connectSharedMemory(name, surfaceID);
//     return info.Env().Undefined();
// }

// Napi::Value destroySharedMemoryJS(const Napi::CallbackInfo& info)
// {
//     const char* name = info[0].ToString().Utf8Value().c_str();

//     destroySharedMemory(name);
//     return info.Env().Undefined();
// }

// Napi::Value moveWindowJS(const Napi::CallbackInfo& info)
// {
//     const char* name = info[0].ToString().Utf8Value().c_str();
//     uint32_t cx = info[1].ToNumber().Uint32Value();
//     uint32_t cy = info[2].ToNumber().Uint32Value();

//     moveWindow(name, cx, cy);
//     return info.Env().Undefined();
// }

// void Init(Napi::Env env, Napi::Object exports) {
//     exports.Set(
//         Napi::String::New(env, "createWindow"),
//         Napi::Function::New(env, createWindowJS));
//     exports.Set(
//         Napi::String::New(env, "destroyWindow"),
//         Napi::Function::New(env, destroyWindowJS));
//     exports.Set(
//         Napi::String::New(env, "connectIOSurface"),
//         Napi::Function::New(env, connectSharedMemoryJS));
//     exports.Set(
//         Napi::String::New(env, "destroyIOSurface"),
//         Napi::Function::New(env, destroySharedMemoryJS));
//     exports.Set(
//         Napi::String::New(env, "moveWindow"),
//         Napi::Function::New(env, moveWindowJS));
// }

// Napi::Object main_node(Napi::Env env, Napi::Object exports) {
//     Init(env, exports);
//     return exports;
// }

#define DECLARE_NAPI_METHOD(name, func)                                        \
  { name, 0, func, 0, 0, 0, napi_default, 0 }

napi_value createWindowJS(napi_env env, napi_callback_info info)
{
    // std::string name = info[0].ToString().Utf8Value();
    // Napi::Buffer<void *> bufferData = info[1].As<Napi::Buffer<void*>>();

    // createWindow(name, bufferData.Data());

    // napi_status status;

    // size_t argc = 2;
    // napi_value args[2];
    // status = napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    // assert(status == napi_ok);

    // if (argc < 2) {
    //   napi_throw_type_error(env, nullptr, "Wrong number of arguments");
    //   return nullptr;
    // }

    // size_t str_size;
    // size_t str_size_read;
    // napi_get_value_string_utf8(env, args[0], NULL, 0, &str_size);
    // char * buf;
    // buf = (char*)calloc(str_size + 1, sizeof(char));
    // str_size = str_size + 1;
    // napi_get_value_string_utf8(env, args[0], buf, str_size, &str_size_read);

    createWindow("", NULL);
    return NULL;
}

napi_value Method(napi_env env, napi_callback_info info) {
  napi_status status;
  napi_value world;
  status = napi_create_string_utf8(env, "world", 5, &world);
  assert(status == napi_ok);
  return world;
}

napi_value Init(napi_env env, napi_value exports) {
  napi_status status;
  napi_property_descriptor desc = DECLARE_NAPI_METHOD("createWindow", createWindowJS);
  status = napi_define_properties(env, exports, 1, &desc);
  assert(status == napi_ok);
  return exports;
}

NAPI_MODULE(windowRendering, Init)

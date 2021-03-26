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

#include "window-osx-int.hpp"
#include "window-osx-obj-c-int.h"

WindowInt::WindowInt(void)
    : _impl (nullptr)
{   }

void WindowInt::init(void)
{
    _impl = new WindowObjCInt();
}

WindowInt::~WindowInt(void)
{
    if (_impl) { delete _impl; _impl = nullptr; }
}

void WindowInt::createWindow(std::string name, void **handle)
{
    _impl->createWindow(name, handle);
}

void WindowInt::destroyWindowSurface(std::string name)
{
    _impl->destroyWindowSurface(name);
}

void WindowInt::connectIOSurfaceJS(std::string name, uint32_t surfaceID)
{
    _impl->connectIOSurfaceJS(name, surfaceID);
}

void WindowInt::moveWindow(std::string name, uint32_t cx, uint32_t cy)
{
    _impl->moveWindow(name, cx, cy);
}
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
        }
    }

    CFRelease(windowList);
}

@end

@implementation WinDel
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // UNUSED_PARAMETER(notification);
    NSLog(@"Application finished launching");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app
{
    // UNUSED_PARAMETER(app);

    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // UNUSED_PARAMETER(sender);
    return NSTerminateNow;
}

@end
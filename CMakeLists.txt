cmake_minimum_required(VERSION 3.0)
project(node_window_rendering)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

#############################
# CMake Settings
#############################

SET(NODEJS_URL "https://atom.io/download/atom-shell" CACHE STRING "Node.JS URL")
SET(NODEJS_NAME "iojs" CACHE STRING "Node.JS Name")
SET(NODEJS_VERSION "v9.3.3" CACHE STRING "Node.JS Version")

include(NodeJS)
include(CPack)

nodejs_init()

#############################
# Source, Libraries & Directories
#############################
SET(PROJECT_SOURCE
	"${PROJECT_SOURCE_DIR}/src/module.c"
	"${PROJECT_SOURCE_DIR}/src/window-rendering.h"
)

SET(PROJECT_LIBRARIES
	${NODEJS_LIBRARIES}
)

SET(PROJECT_INCLUDE_PATHS
	${NODEJS_INCLUDE_DIRS}
	"${CMAKE_SOURCE_DIR}/source/"
)

if(APPLE)
	find_package(OpenGL REQUIRED)
	find_library(COREAUDIO CoreAudio)
	find_library(AUDIOUNIT AudioUnit)
	find_library(COREFOUNDATION CoreFoundation)
	find_library(IOSURF IOSurface)
	find_library(COCOA Cocoa)
	find_library(GLKIT GLKit)

	LIST(APPEND PROJECT_SOURCE
		"${PROJECT_SOURCE_DIR}/src/apple/window-osx.mm"
		"${PROJECT_SOURCE_DIR}/src/apple/window-osx.h"
	)
	LIST(APPEND PROJECT_INCLUDE_PATHS
		${OPENGL_INCLUDE_DIR}
		${COREAUDIO}
		${AUDIOUNIT}
		${COREFOUNDATION}
		${IOSURF}
		${COCOA}
		${GLKIT}
	)
	LIST(APPEND PROJECT_LIBRARIES
		${OPENGL_gl_LIBRARY}
		${COREAUDIO}
		${AUDIOUNIT}
		${COREFOUNDATION}
		${IOSURF}
		${COCOA}
		${GLKIT}
	)
elseif(WIN32)
	LIST(APPEND PROJECT_SOURCE
		"${PROJECT_SOURCE_DIR}/src/windows/window-rendering-win32.c"

	)
	LIST(APPEND PROJECT_LIBRARIES
		dxgi.lib
		d3d11.lib
	)

	if(WIN32)
		add_definitions(-DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS)
	endif()
endif()

#############################
# Building
#############################
add_nodejs_module(
	${PROJECT_NAME}
	${PROJECT_SOURCE}
)

TARGET_LINK_LIBRARIES(
	${PROJECT_NAME}
	${PROJECT_LIBRARIES}
)

TARGET_INCLUDE_DIRECTORIES(
	${PROJECT_NAME}
	PUBLIC ${PROJECT_INCLUDE_PATHS} ${NODE_ADDON_API_DIR}
)
target_compile_definitions(
	${PROJECT_NAME}
	PRIVATE BUILDING_NODE_EXTENSION
)

set(CompilerFlags
        CMAKE_CXX_FLAGS
        CMAKE_CXX_FLAGS_DEBUG
        CMAKE_CXX_FLAGS_RELEASE
		CMAKE_CXX_FLAGS_RELWITHDEBINFO
        CMAKE_C_FLAGS
        CMAKE_C_FLAGS_DEBUG
        CMAKE_C_FLAGS_RELEASE
		CMAKE_C_FLAGS_RELWITHDEBINFO
        )
foreach(CompilerFlag ${CompilerFlags})
  string(REPLACE "/MD" "/MT" ${CompilerFlag} "${${CompilerFlag}}")
endforeach()

SET_TARGET_PROPERTIES(
	${PROJECT_NAME}
	PROPERTIES
	PREFIX ""
	SUFFIX ".node"
)

#############################
# Distribute
#############################
INSTALL(TARGETS ${PROJECT_NAME}
	RUNTIME DESTINATION "./" COMPONENT Runtime
	LIBRARY DESTINATION "./" COMPONENT Runtime
)

# JavaScript
INSTALL(
	FILES "${CMAKE_SOURCE_DIR}/package.json"
	DESTINATION "./"
)
INSTALL(
	FILES "${CMAKE_SOURCE_DIR}/main.js"
	DESTINATION "./"
)

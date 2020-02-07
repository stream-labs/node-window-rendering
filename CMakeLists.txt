cmake_minimum_required(VERSION 3.0)
project(node_window_rendering)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

#############################
# CMake Settings
#############################

SET(NODEJS_URL "https://atom.io/download/atom-shell" CACHE STRING "Node.JS URL")
SET(NODEJS_NAME "iojs" CACHE STRING "Node.JS Name")
SET(NODEJS_VERSION "v6.0.3" CACHE STRING "Node.JS Version")

include(NodeJS)
include(CPack)

nodejs_init()

#############################
# Source, Libraries & Directories
#############################
SET(PROJECT_SOURCE
	"${PROJECT_SOURCE_DIR}/src/module.cpp"
	"${PROJECT_SOURCE_DIR}/src/window-osx.mm"
	"${PROJECT_SOURCE_DIR}/src/window-osx.h"
	"${PROJECT_SOURCE_DIR}/src/window-osx-obj-c-int.h"
	"${PROJECT_SOURCE_DIR}/src/window-osx-int.hpp"
	"${PROJECT_SOURCE_DIR}/src/window-osx-int.cpp"
)

SET(PROJECT_LIBRARIES
	${NODEJS_LIBRARIES}
)

SET(PROJECT_INCLUDE_PATHS
	${NODEJS_INCLUDE_DIRS}
	"${CMAKE_SOURCE_DIR}/source/"
)

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
	PUBLIC ${PROJECT_INCLUDE_PATHS}
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

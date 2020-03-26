brew install wget

mkdir build
cd build

# Configure
cmake .. \
-DCMAKE_OSX_DEPLOYMENT_TARGET=10.11 \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_INSTALL_PREFIX=${DISTRIBUTEDIRECTORY}/node-window-rendering
-DNODEJS_NAME=${RUNTIMENAME} \
-DNODEJS_URL=${RUNTIMEURL} \
-DNODEJS_VERSION=${RUNTIMEVERSION}

cd ..

# Build
cmake --build build --target install --config RelWithDebInfo

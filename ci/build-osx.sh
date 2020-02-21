brew install wget

mkdir build
cd build

# Configure
cmake .. \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_INSTALL_PREFIX=${DISTRIBUTEDIRECTORY}/node-libuiohook
-DNODEJS_NAME=${RUNTIMENAME} \
-DNODEJS_URL=${RUNTIMEURL} \
-DNODEJS_VERSION=${RUNTIMEVERSION}

cd ..

# Build
cmake --build build --target install --config RelWithDebInfo


void createWindow(const char* name, void **handle);
void destroyWindow(const char* name);
void connectSharedMemory(const char* name, int surfaceID);
void destroySharedMemory(const char* name);
void moveWindow(const char* name, int cx, int cy);
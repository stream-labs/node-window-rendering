#include <string>

void createWindow(std::string name, void **handle);
void destroyWindow(std::string name);
void connectSharedMemory(std::string name, uint32_t surfaceID);
void destroySharedMemory(std::string name);
void moveWindow(std::string name, uint32_t cx, uint32_t cy);
#include "../window-rendering.h"
#define INITGUID
#include <dxgi.h>
#include <d3d11.h>
#include <d3d11_1.h>
#include <KnownFolders.h>
#include <ShlObj_core.h>

static HMODULE get_lib(const char *lib)
{
	HMODULE mod = GetModuleHandleA(lib);
	if (mod)
		return mod;

	mod = LoadLibraryA(lib);
	if (!mod)
		return NULL;
	return mod;
}

typedef HRESULT(WINAPI *CREATEDXGIFACTORY1PROC)(REFIID, void **);

void createWindow(const char* name, void **handle)
{
	wchar_t *path;
	if (SHGetKnownFolderPath(&FOLDERID_SystemX86, 0, NULL, &path) != S_OK)
		return;

	SetDllDirectory(path);
	HMODULE dxgi = get_lib("DXGI.dll");
	HMODULE d3d11 = get_lib("D3D11.dll");
	CoTaskMemFree(path);
	SetDllDirectory(NULL);
	CREATEDXGIFACTORY1PROC create_dxgi;
	PFN_D3D11_CREATE_DEVICE create_device;
	IDXGIFactory1 *factory;
	IDXGIAdapter *adapter;
	ID3D11Device *device;
	ID3D11DeviceContext *context;
	HRESULT hr;

	if (!dxgi || !d3d11) {
		return;
	}

	create_dxgi = (CREATEDXGIFACTORY1PROC)GetProcAddress(
		dxgi, "CreateDXGIFactory1");
	create_device = (PFN_D3D11_CREATE_DEVICE)GetProcAddress(
		d3d11, "D3D11CreateDevice");

	if (!create_dxgi || !create_device)
		return;

	hr = create_dxgi(&IID_IDXGIFactory1, (void**)&factory);
	if (FAILED(hr))
		return;

	hr = factory->lpVtbl->EnumAdapters(factory, 0, &adapter);
	factory->lpVtbl->Release(factory);
	if (FAILED(hr))
		return;


	return;
}

void destroyWindow(const char* name)
{

}

void connectSharedMemory(const char* name, int surfaceID)
{

}

void destroySharedMemory(const char* name)
{

}

void moveWindow(const char* name, int cx, int cy)
{

}

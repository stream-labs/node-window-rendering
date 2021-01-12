#include "../window-rendering.h"
#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>

WNDCLASSEX DisplayWndClassObj;
ATOM       DisplayWndClassAtom;

ID3D11Device* pDevice;
IDXGISwapChain* pSwap;
ID3D11DeviceContext* pContext;

char system_path[MAX_PATH] = {0};

LRESULT CALLBACK DisplayWndProc(_In_ HWND hwnd, _In_ UINT uMsg, _In_ WPARAM wParam, _In_ LPARAM lParam)
{
	return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

static inline bool init_system_path(void)
{
	UINT ret = GetSystemDirectoryA(system_path, MAX_PATH);
	if (!ret) {
		return false;
	}

	return true;
}

static inline HMODULE load_system_library(const char *name)
{
	char base_path[MAX_PATH];
	HMODULE module;

	strcpy(base_path, system_path);
	strcat(base_path, "\\");
	strcat(base_path, name);

	module = GetModuleHandleA(base_path);
	if (module)
		return module;

	return LoadLibraryA(base_path);
}

void createWindow(std::string name, void **handle) {
	DisplayWndClassObj.cbSize = sizeof(WNDCLASSEX);
	DisplayWndClassObj.style  = 0;
	DisplayWndClassObj.lpfnWndProc   = DisplayWndProc;
	DisplayWndClassObj.cbClsExtra    = 0;
	DisplayWndClassObj.cbWndExtra    = 0;
	DisplayWndClassObj.hInstance     = NULL; // HINST_THISCOMPONENT;
	DisplayWndClassObj.hIcon         = NULL;
	DisplayWndClassObj.hCursor       = NULL;
	DisplayWndClassObj.hbrBackground = NULL;
	DisplayWndClassObj.lpszMenuName  = NULL;
	DisplayWndClassObj.lpszClassName = TEXT("Win32DisplayClass");
	DisplayWndClassObj.hIconSm       = NULL;

	DisplayWndClassAtom = RegisterClassEx(&DisplayWndClassObj);
	if (!DisplayWndClassAtom)
        return;


    HWND nwr_window = CreateWindowEx(
        0,
        TEXT("Win32DisplayClass"),
        TEXT("NodeWindowRendering"),
        WS_VISIBLE | WS_OVERLAPPEDWINDOW |
        WS_CAPTION | WS_MINIMIZEBOX | WS_SYSMENU,
        500,
        500,
        1280,
        720,
        NULL,
        NULL,
        NULL,
        NULL
    );

    if(!nwr_window)
        return;

    init_system_path();

	HMODULE d3d11 = load_system_library("d3d11.dll");
	if (!d3d11)
		return;

	HMODULE dxgi = load_system_library("dxgi.dll");
	if (!dxgi)
		return;

    int width = 500;
    int height = 500;

	DXGI_SWAP_CHAIN_DESC sd = {};
	sd.BufferDesc.Width = width;
	sd.BufferDesc.Height = height;
	sd.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
	sd.BufferDesc.RefreshRate.Numerator = 0;
	sd.BufferDesc.RefreshRate.Denominator = 0;
	sd.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
	sd.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
	sd.SampleDesc.Count = 1;
	sd.SampleDesc.Quality = 0;
	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	sd.BufferCount = 1;
	sd.OutputWindow = nwr_window;
	sd.Windowed = TRUE;
	sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
	sd.Flags = 0;

	UINT swapCreateFlags = 0u;
	// create device and front/back buffers, and swap chain and rendering context
	D3D11CreateDeviceAndSwapChain(
		nullptr,
		D3D_DRIVER_TYPE_HARDWARE,
		nullptr,
		swapCreateFlags,
		nullptr,
		0,
		D3D11_SDK_VERSION,
		&sd,
		&pSwap,
		&pDevice,
		nullptr,
		&pContext
	);
    
    pSwap->Present(0, 0);
    return;
}

void destroyWindow(std::string name) {

}

void connectSharedMemory(std::string name, uint32_t sharedHandle) {
	IDXGIKeyedMutex *km;
	ID3D11Texture2D *input_tex;
	HRESULT hr;

	hr = pDevice->OpenSharedResource(
						(HANDLE)(uintptr_t)sharedHandle,
						__uuidof(ID3D11Texture2D),
						(void**)&input_tex);
	if (FAILED(hr))
        return;

	D3D11_SHADER_RESOURCE_VIEW_DESC resourceDesc = {};
	// input_tex->GetDesc(&resourceDesc);
	resourceDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	resourceDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	resourceDesc.Texture2D.MipLevels = 1;

	ID3D11ShaderResourceView* g_pTexture; // temp handler
	hr = pDevice->CreateShaderResourceView(input_tex, &resourceDesc, &g_pTexture);
	pContext->PSSetShaderResources( 0, 1, &g_pTexture );

    pSwap->Present(0, 0);
}

void destroySharedMemory(std::string name) {

}

void moveWindow(std::string name, uint32_t cx, uint32_t cy) {

}
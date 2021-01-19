#include "../window-rendering.h"
#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>

WNDCLASSEX DisplayWndClassObj;
ATOM       DisplayWndClassAtom;

HWND nwr_window;
bool shouldRender = false;
char system_path[MAX_PATH] = {0};
uint32_t g_sharedHandle;

ID3D11Device* device_ptr                       = NULL;
ID3D11DeviceContext* device_context_ptr        = NULL;
IDXGISwapChain* swap_chain_ptr                 = NULL;
ID3D11RenderTargetView* render_target_view_ptr = NULL; 
ID3D11ShaderResourceView* shaderRes;

LRESULT CALLBACK DisplayWndProc(_In_ HWND hwnd, _In_ UINT uMsg, _In_ WPARAM wParam, _In_ LPARAM lParam)
{
	if (shouldRender) {
		HRESULT hr;

		ID3D11Texture2D* framebuffer;
		hr = device_ptr->OpenSharedResource((HANDLE)(uintptr_t)g_sharedHandle,
							__uuidof(ID3D11Texture2D),
							(void **)&framebuffer);
		if (FAILED(hr))
			return NULL;

		IDXGIKeyedMutex *km;
		hr = framebuffer->QueryInterface(
			IID_IDXGIKeyedMutex,
			(void**)&km
		);

		framebuffer->SetEvictionPriority(DXGI_RESOURCE_PRIORITY_MAXIMUM);

		km->AcquireSync(0, 5);
		
		D3D11_TEXTURE2D_DESC desc;
		framebuffer->GetDesc(&desc);
		
		ID3D11Texture2D *output_tex;
		hr = device_ptr->CreateTexture2D(&desc, NULL, &output_tex);
		if (FAILED(hr)) return false;

		device_context_ptr->CopyResource(
			(ID3D11Resource *)output_tex,
			(ID3D11Resource *)framebuffer);

		km->ReleaseSync(0);


		D3D11_TEXTURE2D_DESC desc2;
		output_tex->GetDesc(&desc2);

		D3D11_SHADER_RESOURCE_VIEW_DESC resourceDesc = {};
		resourceDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		resourceDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
		resourceDesc.Texture2D.MipLevels = 1;
		hr = device_ptr->CreateShaderResourceView(output_tex, &resourceDesc, &shaderRes);
		if (FAILED(hr))
			return NULL;

		ID3D11SamplerState *m_TexSamplerState;
		D3D11_SAMPLER_DESC sampDesc;
		ZeroMemory( &sampDesc, sizeof(sampDesc) );
		sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
		sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
		sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
		sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;


		hr = device_ptr->CreateSamplerState( &sampDesc, &m_TexSamplerState );
		if (FAILED(hr))
			return NULL;

		// Set the sampler state in the pixel shader.
		device_context_ptr->PSSetSamplers(0, 1, &m_TexSamplerState);
		// device_context_ptr->PSSetShaderResources(0, 1, &shaderRes);

		// device_context_ptr->OMSetRenderTargets( 1, &render_target_view_ptr, NULL );


		D3D11_VIEWPORT viewport = {
			0.0f,
			0.0f,
			1920,
			1080,
			0.0f,
			1.0f
		};
		device_context_ptr->RSSetViewports( 1, &viewport );

		swap_chain_ptr->Present( 0, 0 );
		
	}


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


    nwr_window = CreateWindowEx(
        0,
        TEXT("Win32DisplayClass"),
        TEXT("NodeWindowRendering"),
        WS_VISIBLE | WS_OVERLAPPEDWINDOW |
        WS_CAPTION | WS_MINIMIZEBOX | WS_SYSMENU,
        500,
        500,
        1920,
        1080,
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

	DXGI_SWAP_CHAIN_DESC swap_chain_descr               = { 0 };
	swap_chain_descr.BufferDesc.Format  = DXGI_FORMAT_R8G8B8A8_UNORM; 
	swap_chain_descr.SampleDesc.Count   = 1;                               
	swap_chain_descr.SampleDesc.Quality = 0;                               
	swap_chain_descr.BufferUsage        = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	swap_chain_descr.BufferCount        = 1;                               
	swap_chain_descr.OutputWindow       = nwr_window;                
	swap_chain_descr.Windowed           = true;

	D3D_FEATURE_LEVEL feature_level;
	UINT flags = D3D11_CREATE_DEVICE_SINGLETHREADED;
#if defined( DEBUG ) || defined( _DEBUG )
	flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	HRESULT hr = D3D11CreateDeviceAndSwapChain(
		NULL,
		D3D_DRIVER_TYPE_HARDWARE,
		NULL,
		flags,
		NULL,
		0,
		D3D11_SDK_VERSION,
		&swap_chain_descr,
		&swap_chain_ptr,
		&device_ptr,
		&feature_level,
		&device_context_ptr
	);
	
	if (FAILED(hr))
		return;

    return;
}

void destroyWindow(std::string name) {

}

void connectSharedMemory(std::string name, uint32_t sharedHandle) {
	g_sharedHandle = sharedHandle;
	shouldRender = true;
}

void destroySharedMemory(std::string name) {

}

void moveWindow(std::string name, uint32_t cx, uint32_t cy) {

}
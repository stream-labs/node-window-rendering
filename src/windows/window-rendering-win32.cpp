#include "../window-rendering.h"
#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>

WNDCLASSEX DisplayWndClassObj;
ATOM       DisplayWndClassAtom;

ID3D11Device* pDevice = NULL;
IDXGISwapChain* pSwap = NULL;
ID3D11DeviceContext* pContext = NULL;
ID3D11RenderTargetView* render_target_view_ptr = NULL;
ID3D11InputLayout* input_layout_ptr   = NULL;

float vertex_data_array[] = {
0.0f,  0.5f,  0.0f, // point at top
0.5f, -0.5f,  0.0f, // point at bottom-right
-0.5f, -0.5f,  0.0f, // point at bottom-left
};
UINT vertex_stride              = 3 * sizeof( float );
UINT vertex_offset              = 0;
UINT vertex_count               = 3;

ID3D11Buffer* vertex_buffer_ptr = NULL;

ID3D11VertexShader* vertex_shader_ptr = NULL;
ID3D11PixelShader* pixel_shader_ptr   = NULL;

HWND nwr_window;

bool shouldRender = false;

char system_path[MAX_PATH] = {0};

LRESULT CALLBACK DisplayWndProc(_In_ HWND hwnd, _In_ UINT uMsg, _In_ WPARAM wParam, _In_ LPARAM lParam)
{
	if (shouldRender) {
		/* clear the back buffer to cornflower blue for the new frame */
		float background_colour[4] = {
		0x64 / 255.0f, 0x95 / 255.0f, 0xED / 255.0f, 1.0f };
		pContext->ClearRenderTargetView(
			render_target_view_ptr, background_colour);

		RECT winRect;
		GetClientRect( nwr_window, &winRect );
		D3D11_VIEWPORT viewport = {
		0.0f,
		0.0f,
		( FLOAT )( winRect.right - winRect.left ),
		( FLOAT )( winRect.bottom - winRect.top ),
		0.0f,
		1.0f };
		pContext->RSSetViewports( 1, &viewport );

		pContext->OMSetRenderTargets( 1, &render_target_view_ptr, NULL );

		pContext->IASetPrimitiveTopology(
		D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		pContext->IASetInputLayout( input_layout_ptr );
		pContext->IASetVertexBuffers(
		0,
		1,
		&vertex_buffer_ptr,
		&vertex_stride,
		&vertex_offset );

		pContext->VSSetShader( vertex_shader_ptr, NULL, 0 );
		pContext->PSSetShader( pixel_shader_ptr, NULL, 0 );

		pContext->Draw( vertex_count, 0 );
		pSwap->Present( 1, 0 );
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

	DXGI_SWAP_CHAIN_DESC sd = { 0 };
	//sd.BufferDesc.Width = width;
	//sd.BufferDesc.Height = height;
	sd.BufferDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
	//sd.BufferDesc.RefreshRate.Numerator = 60;
	//sd.BufferDesc.RefreshRate.Denominator = 1;
	//sd.BufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;
	//sd.BufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
	sd.SampleDesc.Count = 1;
	sd.SampleDesc.Quality = 0;
	sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	sd.BufferCount = 1;
	sd.OutputWindow = nwr_window;
	sd.Windowed = TRUE;
	//sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
	//sd.Flags = 0;

	D3D_FEATURE_LEVEL feature_level;
	UINT flags = D3D11_CREATE_DEVICE_SINGLETHREADED;
#if defined( DEBUG ) || defined( _DEBUG )
	flags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

	//UINT swapCreateFlags = 0u;
	// create device and front/back buffers, and swap chain and rendering context
	D3D11CreateDeviceAndSwapChain(
		nullptr,
		D3D_DRIVER_TYPE_HARDWARE,
		nullptr,
		flags,
		nullptr,
		0,
		D3D11_SDK_VERSION,
		&sd,
		&pSwap,
		&pDevice,
		&feature_level,
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
	resourceDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	resourceDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	resourceDesc.Texture2D.MipLevels = 1;

	ID3D11ShaderResourceView *shaderRes;

	hr = pDevice->CreateShaderResourceView(input_tex, &resourceDesc, &shaderRes);
	if (FAILED(hr))
		return;

	D3D11_RENDER_TARGET_VIEW_DESC rtv;
	rtv.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	rtv.ViewDimension = D3D11_RTV_DIMENSION_TEXTURE2D;
	rtv.Texture2D.MipSlice = 0;

	//ID3D11RenderTargetView *renderTarget;

	ID3D11Texture2D* framebuffer;
	hr = pSwap->GetBuffer(
		0,
		__uuidof(ID3D11Texture2D),
		(void**)&framebuffer);
	if (FAILED(hr))
		return;

	hr = pDevice->CreateRenderTargetView(
		framebuffer, 0, &render_target_view_ptr);
	if (FAILED(hr))
		return;

	framebuffer->Release();


	UINT flags2 = D3DCOMPILE_ENABLE_STRICTNESS;
	#if defined( DEBUG ) || defined( _DEBUG )
		flags2 |= D3DCOMPILE_DEBUG; // add more debug output
	#endif
		ID3DBlob *vs_blob_ptr = NULL, *ps_blob_ptr = NULL, *error_blob = NULL;

    // COMPILE VERTEX SHADER
    hr = D3DCompileFromFile(
      L"shaders.hlsl",
      nullptr,
      D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "vs_main",
      "vs_5_0",
      flags2,
      0,
      &vs_blob_ptr,
      &error_blob );
    if ( FAILED( hr ) ) {
      if ( error_blob ) {
        OutputDebugStringA( (char*)error_blob->GetBufferPointer() );
        error_blob->Release();
      }
      if ( vs_blob_ptr ) { vs_blob_ptr->Release(); }
    //   assert( false );
    }

    // COMPILE PIXEL SHADER
    hr = D3DCompileFromFile(
      L"shaders.hlsl",
      nullptr,
      D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "ps_main",
      "ps_5_0",
      flags2,
      0,
      &ps_blob_ptr,
      &error_blob );
    if ( FAILED( hr ) ) {
      if ( error_blob ) {
        OutputDebugStringA( (char*)error_blob->GetBufferPointer() );
        error_blob->Release();
      }
      if ( ps_blob_ptr ) { ps_blob_ptr->Release(); }
    //   assert( false );
    }
	
	hr = pDevice->CreateVertexShader(
	vs_blob_ptr->GetBufferPointer(),
	vs_blob_ptr->GetBufferSize(),
	NULL,
	&vertex_shader_ptr );
	if (FAILED(hr))
		return;

	hr = pDevice->CreatePixelShader(
	ps_blob_ptr->GetBufferPointer(),
	ps_blob_ptr->GetBufferSize(),
	NULL,
	&pixel_shader_ptr );
	if (FAILED(hr))
		return;

	D3D11_INPUT_ELEMENT_DESC inputElementDesc[] = {
	{ "POS", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	/*
	{ "COL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	{ "NOR", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	{ "TEX", 0, DXGI_FORMAT_R32G32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
	*/
	};
	hr = pDevice->CreateInputLayout(
	inputElementDesc,
	ARRAYSIZE( inputElementDesc ),
	vs_blob_ptr->GetBufferPointer(),
	vs_blob_ptr->GetBufferSize(),
	&input_layout_ptr );
	if (FAILED(hr))
		return;

	{ /*** load mesh data into vertex buffer **/
	D3D11_BUFFER_DESC vertex_buff_descr     = {};
	vertex_buff_descr.ByteWidth             = sizeof( vertex_data_array );
	vertex_buff_descr.Usage                 = D3D11_USAGE_DEFAULT;
	vertex_buff_descr.BindFlags             = D3D11_BIND_VERTEX_BUFFER;
	D3D11_SUBRESOURCE_DATA sr_data          = { 0 };
	sr_data.pSysMem                         = vertex_data_array;
	HRESULT hr = pDevice->CreateBuffer(
		&vertex_buff_descr,
		&sr_data,
		&vertex_buffer_ptr );
	if (FAILED(hr))
		return;
	}

	shouldRender = true;
}

void destroySharedMemory(std::string name) {

}

void moveWindow(std::string name, uint32_t cx, uint32_t cy) {

}
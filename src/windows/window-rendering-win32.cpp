#include "../window-rendering.h"
#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <d3dcompiler.h>
#include <directxmath.h>

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

ID3D11Texture2D* depthStencilBuffer;
ID3D11DepthStencilView* depthStencilView;

ID3D10Blob* VS_Buffer;
ID3D10Blob* PS_Buffer;

ID3D11VertexShader* VS;
ID3D11PixelShader* PS;

ID3D11Buffer* squareIndexBuffer;
ID3D11Buffer* squareVertBuffer;
ID3D11InputLayout* vertLayout;
ID3D11Buffer* cbPerObjectBuffer;

DirectX::XMMATRIX WVP;
DirectX::XMMATRIX cube1World;
DirectX::XMMATRIX cube2World;
DirectX::XMMATRIX camView;
DirectX::XMMATRIX camProjection;

DirectX::XMVECTOR camPosition;
DirectX::XMVECTOR camTarget;
DirectX::XMVECTOR camUp;

DirectX::XMMATRIX Rotation;
DirectX::XMMATRIX Scale;
DirectX::XMMATRIX Translation;
float rot = 0.01f;

ID3D11SamplerState* CubesTexSamplerState;

struct cbPerObject
{
	DirectX::XMMATRIX  WVP;
};

cbPerObject cbPerObj;

///////////////**************new**************////////////////////
//Vertex Structure and Vertex Layout (Input Layout)//
struct Vertex	//Overloaded Vertex Structure
{
	Vertex(){}
	Vertex(float x, float y, float z,
		float u, float v)
		: pos(x,y,z), texCoord(u, v){}

	DirectX::XMFLOAT3 pos;
	DirectX::XMFLOAT2 texCoord;
};

D3D11_INPUT_ELEMENT_DESC layout[] =
{
	{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },  
	{ "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },  
};
UINT numElements = ARRAYSIZE(layout);

void UpdateScene()
{
	//Keep the cubes rotating
	// rot += .0005f;
	// if(rot > 6.26f)
	// 	rot = 0.0f;

	//Reset cube1World
	cube1World = DirectX::XMMatrixIdentity();

	//Define cube1's world space matrix
	DirectX::XMVECTOR rotaxis = DirectX::XMVectorSet(0.0f, 0.0f, 0.0f, 0.0f);
	Rotation = DirectX::XMMatrixRotationAxis( rotaxis, rot);
	Translation = DirectX::XMMatrixTranslation( 0.0f, 0.0f, 4.0f );

	//Set cube1's world space using the transformations
	cube1World = Translation * Rotation;

	//Reset cube2World
	cube2World = DirectX::XMMatrixIdentity();

	//Define cube2's world space matrix
	Rotation = DirectX::XMMatrixRotationAxis( rotaxis, -rot);
	Scale = DirectX::XMMatrixScaling( 1.0f, 1.0f, 1.0f );

	//Set cube2's world space matrix
	cube2World = Rotation * Scale;
}

void DrawScene() {
		HRESULT hr;

		//Clear our backbuffer
		float bgColor[4] = {(200.0f, 200.0f, 200.0f, 1.0f)};
		device_context_ptr->ClearRenderTargetView(render_target_view_ptr, bgColor);

		//Refresh the Depth/Stencil view
		device_context_ptr->ClearDepthStencilView(depthStencilView, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 1.0f, 0);

		//Set the WVP matrix and send it to the constant buffer in effect file
		WVP = cube1World * camView * camProjection;
		cbPerObj.WVP = XMMatrixTranspose(WVP);	
		device_context_ptr->UpdateSubresource( cbPerObjectBuffer, 0, NULL, &cbPerObj, 0, 0 );
		device_context_ptr->VSSetConstantBuffers( 0, 1, &cbPerObjectBuffer );
		///////////////**************new**************////////////////////
		device_context_ptr->PSSetShaderResources( 0, 1, &shaderRes );
		device_context_ptr->PSSetSamplers( 0, 1, &CubesTexSamplerState );
		///////////////**************new**************////////////////////

		//Draw the first cube
		device_context_ptr->DrawIndexed( 36, 0, 0 );

		// WVP = cube2World * camView * camProjection;
		// cbPerObj.WVP = XMMatrixTranspose(WVP);	
		// device_context_ptr->UpdateSubresource( cbPerObjectBuffer, 0, NULL, &cbPerObj, 0, 0 );
		// device_context_ptr->VSSetConstantBuffers( 0, 1, &cbPerObjectBuffer );
		// ///////////////**************new**************////////////////////
		// device_context_ptr->PSSetShaderResources( 0, 1, &shaderRes );
		// device_context_ptr->PSSetSamplers( 0, 1, &CubesTexSamplerState );
		///////////////**************new**************////////////////////

		//Draw the second cube
		// device_context_ptr->DrawIndexed( 36, 0, 0 );

		//Present the backbuffer to the screen
		swap_chain_ptr->Present(0, 0);
}

LRESULT CALLBACK DisplayWndProc(_In_ HWND hwnd, _In_ UINT uMsg, _In_ WPARAM wParam, _In_ LPARAM lParam)
{
	if (shouldRender) {
		UpdateScene();
		DrawScene();
		// HRESULT hr;

		// ID3D11Texture2D* framebuffer;
		// hr = device_ptr->OpenSharedResource((HANDLE)(uintptr_t)g_sharedHandle,
		// 					__uuidof(ID3D11Texture2D),
		// 					(void **)&framebuffer);
		// if (FAILED(hr))
		// 	return NULL;

		// IDXGIKeyedMutex *km;
		// hr = framebuffer->QueryInterface(
		// 	IID_IDXGIKeyedMutex,
		// 	(void**)&km
		// );

		// framebuffer->SetEvictionPriority(DXGI_RESOURCE_PRIORITY_MAXIMUM);

		// km->AcquireSync(0, 5);
		
		// D3D11_TEXTURE2D_DESC desc;
		// framebuffer->GetDesc(&desc);
		
		// ID3D11Texture2D *output_tex;
		// hr = device_ptr->CreateTexture2D(&desc, NULL, &output_tex);
		// if (FAILED(hr)) return false;

		// device_context_ptr->CopyResource(
		// 	(ID3D11Resource *)output_tex,
		// 	(ID3D11Resource *)framebuffer);

		// km->ReleaseSync(0);


		// D3D11_TEXTURE2D_DESC desc2;
		// output_tex->GetDesc(&desc2);

		// D3D11_SHADER_RESOURCE_VIEW_DESC resourceDesc = {};
		// resourceDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
		// resourceDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
		// resourceDesc.Texture2D.MipLevels = 1;
		// hr = device_ptr->CreateShaderResourceView(output_tex, &resourceDesc, &shaderRes);
		// if (FAILED(hr))
		// 	return NULL;

		// ID3D11SamplerState *m_TexSamplerState;
		// D3D11_SAMPLER_DESC sampDesc;
		// ZeroMemory( &sampDesc, sizeof(sampDesc) );
		// sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
		// sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
		// sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
		// sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;


		// hr = device_ptr->CreateSamplerState( &sampDesc, &m_TexSamplerState );
		// if (FAILED(hr))
		// 	return NULL;

		// // Set the sampler state in the pixel shader.
		// device_context_ptr->PSSetSamplers(0, 1, &m_TexSamplerState);
		// // device_context_ptr->PSSetShaderResources(0, 1, &shaderRes);

		// // device_context_ptr->OMSetRenderTargets( 1, &render_target_view_ptr, NULL );


		// D3D11_VIEWPORT viewport = {
		// 	0.0f,
		// 	0.0f,
		// 	1920,
		// 	1080,
		// 	0.0f,
		// 	1.0f
		// };
		// device_context_ptr->RSSetViewports( 1, &viewport );

		// swap_chain_ptr->Present( 0, 0 );

		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////////////////////

		// //Clear our backbuffer
		// float bgColor[4] = {(0.0f, 0.0f, 0.0f, 0.0f)};
		// device_context_ptr->ClearRenderTargetView(render_target_view_ptr, bgColor);

		// //Refresh the Depth/Stencil view
		// device_context_ptr->ClearDepthStencilView(depthStencilView, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 1.0f, 0);

		// //Set the WVP matrix and send it to the constant buffer in effect file
		// WVP = cube1World * camView * camProjection;
		// cbPerObj.WVP = XMMatrixTranspose(WVP);	
		// device_context_ptr->UpdateSubresource( cbPerObjectBuffer, 0, NULL, &cbPerObj, 0, 0 );
		// device_context_ptr->VSSetConstantBuffers( 0, 1, &cbPerObjectBuffer );
		// ///////////////**************new**************////////////////////
		// device_context_ptr->PSSetShaderResources( 0, 1, &shaderRes );
		// device_context_ptr->PSSetSamplers( 0, 1, &CubesTexSamplerState );
		// ///////////////**************new**************////////////////////

		// //Draw the first cube
		// device_context_ptr->DrawIndexed( 36, 0, 0 );

		// WVP = cube2World * camView * camProjection;
		// cbPerObj.WVP = XMMatrixTranspose(WVP);	
		// device_context_ptr->UpdateSubresource( cbPerObjectBuffer, 0, NULL, &cbPerObj, 0, 0 );
		// device_context_ptr->VSSetConstantBuffers( 0, 1, &cbPerObjectBuffer );
		// ///////////////**************new**************////////////////////
		// device_context_ptr->PSSetShaderResources( 0, 1, &shaderRes );
		// device_context_ptr->PSSetSamplers( 0, 1, &CubesTexSamplerState );
		// ///////////////**************new**************////////////////////

		// //Draw the second cube
		// device_context_ptr->DrawIndexed( 36, 0, 0 );

		// //Present the backbuffer to the screen
		// swap_chain_ptr->Present(0, 0);
		
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
        0,
        0,
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

	// DXGI_SWAP_CHAIN_DESC swap_chain_descr               = { 0 };
	// swap_chain_descr.BufferDesc.Format  = DXGI_FORMAT_R8G8B8A8_UNORM; 
	// swap_chain_descr.SampleDesc.Count   = 1;                               
	// swap_chain_descr.SampleDesc.Quality = 0;                               
	// swap_chain_descr.BufferUsage        = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	// swap_chain_descr.BufferCount        = 1;                               
	// swap_chain_descr.OutputWindow       = nwr_window;                
	// swap_chain_descr.Windowed           = true;

	//Describe our SwapChain Buffer
	DXGI_MODE_DESC bufferDesc;

	ZeroMemory(&bufferDesc, sizeof(DXGI_MODE_DESC));

	bufferDesc.Width = 1920;
	bufferDesc.Height = 1080;
	bufferDesc.RefreshRate.Numerator = 60;
	bufferDesc.RefreshRate.Denominator = 1;
	bufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	bufferDesc.ScanlineOrdering = DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED;
	bufferDesc.Scaling = DXGI_MODE_SCALING_UNSPECIFIED;

	//Describe our SwapChain
	DXGI_SWAP_CHAIN_DESC swap_chain_descr; 

	ZeroMemory(&swap_chain_descr, sizeof(DXGI_SWAP_CHAIN_DESC));

	swap_chain_descr.BufferDesc = bufferDesc;
	swap_chain_descr.SampleDesc.Count = 1;
	swap_chain_descr.SampleDesc.Quality = 0;
	swap_chain_descr.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
	swap_chain_descr.BufferCount = 1;
	swap_chain_descr.OutputWindow = nwr_window; 
	swap_chain_descr.Windowed = TRUE; 
	// swap_chain_descr.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

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
	HRESULT hr;

	//Create our BackBuffer
	ID3D11Texture2D* framebuffer;
	hr = swap_chain_ptr->GetBuffer( 0, __uuidof( ID3D11Texture2D ), (void**)&framebuffer );
	if (FAILED(hr))
		return;

	//Create our Render Target
	hr = device_ptr->CreateRenderTargetView( framebuffer, NULL, &render_target_view_ptr );
	framebuffer->Release();

	//Describe our Depth/Stencil Buffer
	D3D11_TEXTURE2D_DESC depthStencilDesc;

	depthStencilDesc.Width     = 1920;
	depthStencilDesc.Height    = 1080;
	depthStencilDesc.MipLevels = 1;
	depthStencilDesc.ArraySize = 1;
	depthStencilDesc.Format    = DXGI_FORMAT_D24_UNORM_S8_UINT;
	depthStencilDesc.SampleDesc.Count   = 1;
	depthStencilDesc.SampleDesc.Quality = 0;
	depthStencilDesc.Usage          = D3D11_USAGE_DEFAULT;
	depthStencilDesc.BindFlags      = D3D11_BIND_DEPTH_STENCIL;
	depthStencilDesc.CPUAccessFlags = 0; 
	depthStencilDesc.MiscFlags      = 0;

	//Create the Depth/Stencil View
	hr = device_ptr->CreateTexture2D(&depthStencilDesc, NULL, &depthStencilBuffer);
	if (FAILED(hr))
		return;
	hr = device_ptr->CreateDepthStencilView(depthStencilBuffer, NULL, &depthStencilView);
	if (FAILED(hr))
		return;

	//Set our Render Target
	device_context_ptr->OMSetRenderTargets( 1, &render_target_view_ptr, depthStencilView );

	// Init Scene
	// hr = D3DX11CompileFromFile(L"Effects.fx", 0, 0, "VS", "vs_4_0", 0, 0, 0, &VS_Buffer, 0, 0);
	// hr = D3DX11CompileFromFile(L"Effects.fx", 0, 0, "PS", "ps_4_0", 0, 0, 0, &PS_Buffer, 0, 0);

    hr = D3DCompileFromFile(
      L"Effects.fx",
      nullptr,
      D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "VS",
      "vs_4_0",
      0,
      0,
      &VS_Buffer,
      0
	);
	if (FAILED(hr))
		return;

    hr = D3DCompileFromFile(
      L"Effects.fx",
      nullptr,
      D3D_COMPILE_STANDARD_FILE_INCLUDE,
      "PS",
      "ps_4_0",
      0,
      0,
      &PS_Buffer,
      0
	);
	if (FAILED(hr))
		return;

	hr = device_ptr->CreateVertexShader(VS_Buffer->GetBufferPointer(), VS_Buffer->GetBufferSize(), NULL, &VS);
	hr = device_ptr->CreatePixelShader(PS_Buffer->GetBufferPointer(), PS_Buffer->GetBufferSize(), NULL, &PS);

	//Set Vertex and Pixel Shaders
	device_context_ptr->VSSetShader(VS, 0, 0);
	device_context_ptr->PSSetShader(PS, 0, 0);

	///////////////**************new**************////////////////////
	//Create the vertex buffer
	Vertex v[] =
	{
		// Front Face
		Vertex(-1.0f, -1.0f, -1.0f, 0.0f, 1.0f),
		Vertex(-1.0f,  1.0f, -1.0f, 0.0f, 0.0f),
		Vertex( 1.0f,  1.0f, -1.0f, 1.0f, 0.0f),
		Vertex( 1.0f, -1.0f, -1.0f, 1.0f, 1.0f),

		// Back Face
		Vertex(-1.0f, -1.0f, 1.0f, 1.0f, 1.0f),
		Vertex( 1.0f, -1.0f, 1.0f, 0.0f, 1.0f),
		Vertex( 1.0f,  1.0f, 1.0f, 0.0f, 0.0f),
		Vertex(-1.0f,  1.0f, 1.0f, 1.0f, 0.0f),

		// Top Face
		Vertex(-1.0f, 1.0f, -1.0f, 0.0f, 1.0f),
		Vertex(-1.0f, 1.0f,  1.0f, 0.0f, 0.0f),
		Vertex( 1.0f, 1.0f,  1.0f, 1.0f, 0.0f),
		Vertex( 1.0f, 1.0f, -1.0f, 1.0f, 1.0f),

		// Bottom Face
		Vertex(-1.0f, -1.0f, -1.0f, 1.0f, 1.0f),
		Vertex( 1.0f, -1.0f, -1.0f, 0.0f, 1.0f),
		Vertex( 1.0f, -1.0f,  1.0f, 0.0f, 0.0f),
		Vertex(-1.0f, -1.0f,  1.0f, 1.0f, 0.0f),

		// Left Face
		Vertex(-1.0f, -1.0f,  1.0f, 0.0f, 1.0f),
		Vertex(-1.0f,  1.0f,  1.0f, 0.0f, 0.0f),
		Vertex(-1.0f,  1.0f, -1.0f, 1.0f, 0.0f),
		Vertex(-1.0f, -1.0f, -1.0f, 1.0f, 1.0f),

		// Right Face
		Vertex( 1.0f, -1.0f, -1.0f, 0.0f, 1.0f),
		Vertex( 1.0f,  1.0f, -1.0f, 0.0f, 0.0f),
		Vertex( 1.0f,  1.0f,  1.0f, 1.0f, 0.0f),
		Vertex( 1.0f, -1.0f,  1.0f, 1.0f, 1.0f),
	};

	DWORD indices[] = {
		// Front Face
		0,  1,  2,
		0,  2,  3,

		// Back Face
		4,  5,  6,
		4,  6,  7,

		// Top Face
		8,  9, 10,
		8, 10, 11,

		// Bottom Face
		12, 13, 14,
		12, 14, 15,

		// Left Face
		16, 17, 18,
		16, 18, 19,

		// Right Face
		20, 21, 22,
		20, 22, 23
	};

	D3D11_BUFFER_DESC indexBufferDesc;
	ZeroMemory( &indexBufferDesc, sizeof(indexBufferDesc) );

	indexBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	indexBufferDesc.ByteWidth = sizeof(DWORD) * 12 * 3;
	indexBufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
	indexBufferDesc.CPUAccessFlags = 0;
	indexBufferDesc.MiscFlags = 0;

	D3D11_SUBRESOURCE_DATA iinitData;

	iinitData.pSysMem = indices;
	device_ptr->CreateBuffer(&indexBufferDesc, &iinitData, &squareIndexBuffer);

	device_context_ptr->IASetIndexBuffer( squareIndexBuffer, DXGI_FORMAT_R32_UINT, 0);


	D3D11_BUFFER_DESC vertexBufferDesc;
	ZeroMemory( &vertexBufferDesc, sizeof(vertexBufferDesc) );

	vertexBufferDesc.Usage = D3D11_USAGE_DEFAULT;
	vertexBufferDesc.ByteWidth = sizeof( Vertex ) * 24;
	vertexBufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	vertexBufferDesc.CPUAccessFlags = 0;
	vertexBufferDesc.MiscFlags = 0;
	///////////////**************new**************////////////////////

	D3D11_SUBRESOURCE_DATA vertexBufferData; 

	ZeroMemory( &vertexBufferData, sizeof(vertexBufferData) );
	vertexBufferData.pSysMem = v;
	hr = device_ptr->CreateBuffer( &vertexBufferDesc, &vertexBufferData, &squareVertBuffer);

	//Set the vertex buffer
	UINT stride = sizeof( Vertex );
	UINT offset = 0;
	device_context_ptr->IASetVertexBuffers( 0, 1, &squareVertBuffer, &stride, &offset );

	//Create the Input Layout
	hr = device_ptr->CreateInputLayout( layout, numElements, VS_Buffer->GetBufferPointer(), 
		VS_Buffer->GetBufferSize(), &vertLayout );

	//Set the Input Layout
	device_context_ptr->IASetInputLayout( vertLayout );

	//Set Primitive Topology
	device_context_ptr->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );


	//Create the Viewport
	D3D11_VIEWPORT viewport;
	ZeroMemory(&viewport, sizeof(D3D11_VIEWPORT));

	viewport.TopLeftX = 0;
	viewport.TopLeftY = 0;
	viewport.Width = 1920;
	viewport.Height = 1080;
	viewport.MinDepth = 0.0f;
	viewport.MaxDepth = 1.0f;

	//Set the Viewport
	device_context_ptr->RSSetViewports(1, &viewport);

	//Create the buffer to send to the cbuffer in effect file
	D3D11_BUFFER_DESC cbbd;	
	ZeroMemory(&cbbd, sizeof(D3D11_BUFFER_DESC));

	cbbd.Usage = D3D11_USAGE_DEFAULT;
	cbbd.ByteWidth = sizeof(cbPerObject);
	cbbd.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
	cbbd.CPUAccessFlags = 0;
	cbbd.MiscFlags = 0;

	hr = device_ptr->CreateBuffer(&cbbd, NULL, &cbPerObjectBuffer);

	//Camera information
	camPosition = DirectX::XMVectorSet( 0.0f, 3.0f, -8.0f, 0.0f );
	camTarget = DirectX::XMVectorSet( 0.0f, 0.0f, 0.0f, 0.0f );
	camUp = DirectX::XMVectorSet( 0.0f, 1.0f, 0.0f, 0.0f );

	//Set the View matrix
	camView = DirectX::XMMatrixLookAtLH( camPosition, camTarget, camUp );

	//Set the Projection matrix
	camProjection = DirectX::XMMatrixPerspectiveFovLH( 0.4f*3.14f, 1920/1080, 1.0f, 1000.0f);

	///////////////**************new**************////////////////////
	// hr = D3DX11CreateShaderResourceViewFromFile( d3d11Device, L"braynzar.jpg",
	// 	NULL, NULL, &CubesTexture, NULL );

		
	D3D11_SHADER_RESOURCE_VIEW_DESC resourceDesc = {};
	resourceDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
	resourceDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	resourceDesc.Texture2D.MipLevels = 1;

	ID3D11Texture2D* output_tex;
	hr = device_ptr->OpenSharedResource((HANDLE)(uintptr_t)g_sharedHandle,
						__uuidof(ID3D11Texture2D),
						(void **)&output_tex);
	if (FAILED(hr))
		return;

	hr = device_ptr->CreateShaderResourceView(output_tex, &resourceDesc, &shaderRes);
	if (FAILED(hr))
		return;

	// Describe the Sample State
	D3D11_SAMPLER_DESC sampDesc;
	ZeroMemory( &sampDesc, sizeof(sampDesc) );
	sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
	sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
	sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_NEVER;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;
    
	//Create the Sample State
	hr = device_ptr->CreateSamplerState( &sampDesc, &CubesTexSamplerState );
	///////////////**************new**************////////////////////

	shouldRender = true;
}

void destroySharedMemory(std::string name) {

}

void moveWindow(std::string name, uint32_t cx, uint32_t cy) {

}
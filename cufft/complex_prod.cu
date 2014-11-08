#include "luaT.h"
#include "THC/THC.h"
#include <cufft.h>
#include "fft_prod2.cu"
#include "fill_hermitian.cu"
#include "modulus.cu"
#include "complexInterp.cu"

/* Performs the equivalent of the following Torch code:
for s=1,nMinibatch do
    for i = 1,nOutputPlanes do
        for j = 1,nInputPlanes do
            complex.addcmul(input[s][j],kernel[i][j],output[s][i])
        end
    end
end

where input size is  [nMinibatch x nInputPlanes x nRows x nCols x 2]
	  kernel size is [nOutputPlanes x nInputPlanes x nRows x nCols x 2]
	  output size is [nMinibatch x nOutputPlanes x nRows x nCols x 2]

This can be thought of as a matrix multiplication between the input and kernel, 
where each entry to the matrix is a 2D complex matrix and scalar product is replaced by 
pointwise complex product.

Note this operation is used during fprop, updateGradInput and accGradParameters when 
training in Fourier domain.
*/

static int prod_fprop(lua_State *L) {
	THCudaTensor *input = (THCudaTensor *)luaT_checkudata(L, 1, "torch.CudaTensor");	
	THCudaTensor *weight = (THCudaTensor *)luaT_checkudata(L, 2, "torch.CudaTensor");
	THCudaTensor *output = (THCudaTensor *)luaT_checkudata(L, 3, "torch.CudaTensor");
    bool conjWeight = lua_toboolean(L,4);

	luaL_argcheck(L, input->nDimension == 5, 2, "input should be 4D complex tensor");
	luaL_argcheck(L, output->nDimension == 5, 2, "output should be 4D complex tensor");
	luaL_argcheck(L, weight->nDimension == 5, 2, "kernel should be 4D complex tensor");

	long nMinibatch = input->size[0];
	long nOutputPlanes = weight->size[0];
	long nInputPlanes = weight->size[1];
	long nRows = input->size[2];
	long nCols = input->size[3];

	// raw pointers
	cuComplex *input_data = (cuComplex*)THCudaTensor_data(input);
	cuComplex *weight_data = (cuComplex*)THCudaTensor_data(weight);
	cuComplex *output_data = (cuComplex*)THCudaTensor_data(output);
	
	fourier_prod(input_data, weight_data, output_data, nRows, nCols,
				nMinibatch, nInputPlanes*nRows*nCols, nOutputPlanes*nRows*nCols,
				nInputPlanes, nRows*nCols, nRows*nCols, 
                nOutputPlanes, nInputPlanes*nRows*nCols, nRows*nCols,conjWeight);

	return 0;
}

static int prod_bprop(lua_State *L) {
	THCudaTensor *gradOutput = (THCudaTensor *)luaT_checkudata(L, 1, "torch.CudaTensor");	
	THCudaTensor *weight = (THCudaTensor *)luaT_checkudata(L, 2, "torch.CudaTensor");
	THCudaTensor *gradInput = (THCudaTensor *)luaT_checkudata(L, 3, "torch.CudaTensor");
    bool conjWeight = lua_toboolean(L, 4);

	luaL_argcheck(L, gradInput->nDimension == 5, 2, "gradInput should be 4D complex tensor");
	luaL_argcheck(L, weight->nDimension == 5, 2, "weight should be 4D complex tensor");
	luaL_argcheck(L, gradOutput->nDimension == 5, 2, "gradOutput should be 4D complex tensor");

	long nMinibatch = gradInput->size[0];
	long nOutputPlanes = weight->size[0];
	long nInputPlanes = weight->size[1];
	long nRows = gradInput->size[2];
	long nCols = gradInput->size[3];

	// raw pointers
	cuComplex *gradOutput_data = (cuComplex*)THCudaTensor_data(gradOutput);
	cuComplex *weight_data = (cuComplex*)THCudaTensor_data(weight);
	cuComplex *gradInput_data = (cuComplex*)THCudaTensor_data(gradInput);
	
	fourier_prod(gradOutput_data, weight_data, gradInput_data, nRows, nCols,
				nMinibatch, nOutputPlanes*nRows*nCols, nInputPlanes*nRows*nCols,
				nOutputPlanes, nRows*nCols, nRows*nCols*nInputPlanes, 
                nInputPlanes, nRows*nCols, nRows*nCols,conjWeight);

	return 0;
}

static int prod_accgrad(lua_State *L) {
	THCudaTensor *input = (THCudaTensor *)luaT_checkudata(L, 1, "torch.CudaTensor");	
	THCudaTensor *gradOutput = (THCudaTensor *)luaT_checkudata(L, 2, "torch.CudaTensor");
	THCudaTensor *gradWeight = (THCudaTensor *)luaT_checkudata(L, 3, "torch.CudaTensor");
    int conjGradOutput = lua_toboolean(L, 4);

	luaL_argcheck(L, input->nDimension == 5, 2, "input should be 4D complex tensor");
	luaL_argcheck(L, gradOutput->nDimension == 5, 2, "gradOutput should be 4D complex tensor");
	luaL_argcheck(L, gradWeight->nDimension == 5, 2, "gradWeight should be 4D complex tensor");

	long nMinibatch = input->size[0];
	long nOutputPlanes = gradWeight->size[0];
	long nInputPlanes = gradWeight->size[1];
	long nRows = input->size[2];
	long nCols = input->size[3];

	// raw pointers
	cuComplex *input_data = (cuComplex*)THCudaTensor_data(input);
	cuComplex *gradOutput_data = (cuComplex*)THCudaTensor_data(gradOutput);
	cuComplex *gradWeight_data = (cuComplex*)THCudaTensor_data(gradWeight);
	
	fourier_prod(input_data, gradOutput_data, gradWeight_data, nRows, nCols,
				nInputPlanes, nRows*nCols, nRows*nCols,
				nMinibatch, nInputPlanes*nRows*nCols, nOutputPlanes*nRows*nCols, 
                nOutputPlanes, nRows*nCols, nInputPlanes*nRows*nCols,conjGradOutput);

	return 0;
}


static int fill_hermitian(lua_State *L) {
  THCudaTensor *input = (THCudaTensor *)luaT_checkudata(L, 1, "torch.CudaTensor");	
  THCudaTensor *output = (THCudaTensor *)luaT_checkudata(L, 2, "torch.CudaTensor");

  luaL_argcheck(L, THCudaTensor_isContiguous(input), 1, "input must be contiguous");
  luaL_argcheck(L, THCudaTensor_isContiguous(output),2, "output must be contiguous");
  luaL_argcheck(L, input->nDimension == 5, 2, "input should be 4D complex tensor");
  luaL_argcheck(L, output->nDimension == 5, 2, "output should be 4D complex tensor");
  luaL_argcheck(L, input->size[3] == output->size[3]/2+1, 2, "input must have N/2+1 columns");

  long nMinibatch = input->size[0];
  long nInputPlanes = input->size[1];
  long nRows = output->size[2];
  long nCols = output->size[3];
  cuComplex *input_data = (cuComplex*)THCudaTensor_data(input);
  cuComplex *output_data = (cuComplex*)THCudaTensor_data(output);
   
  fill_hermitian_call(input_data, output_data, nMinibatch*nInputPlanes,nRows,nCols);

  return 0;
}




static const struct luaL_reg cucomplex [] = {
	{"prod_fprop", prod_fprop},
	{"prod_bprop", prod_bprop},
	{"prod_accgrad",prod_accgrad},
    {"fill_hermitian",fill_hermitian},
    {"modulus_updateGradInput",modulus_updateGradInput},
    {"complexInterp_interpolate",complexInterp_interpolate},
	{NULL, NULL}
};

LUA_EXTERNC int luaopen_cucomplex(lua_State *L) {
	luaL_openlib(L,"cucomplex",cucomplex,0);
	return 1;
}





	

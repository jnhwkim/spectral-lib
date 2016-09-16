# spectral-lib

`spectral-lib` provides Torch7 wrappers for CuFFT including FFT1d batch version. 

### Revision History

* change function name of `torch.find` to `torch.find1d` to avoid a conflict with `torch.find` of package `torchx` (v0.1).

======================

You are welcome to use this code for research purposes but it is not actively supported. 

### Instalation

Your torch version must be installed with `TORCH_LUA_VERSION=LUA51`. (See mbhenaff/spectral-lib#11)

Clone the repo, cd to it and then run:

`luarocks install spectralnet-scm-1.rockspec`

To run on MNIST/CIFAR, download the datasets and change the paths in test/datasource.lua

You can get the datasets here:

https://github.com/torch/tutorials/tree/master/A_datasets

There are Matlab scripts with examples how to build the graphs in mresgraph. 

To train the models, run test/train.lua. The hyperparameters are in params.lua. 

# spectral-lib

`spectral-lib` provides Torch7 wrappers for CuFFT including FFT1d batch version. 

### Revision History

* change function name of `torch.find` to `torch.find1d` to avoid a conflict with `torch.find` of package `torchx` (v0.1).

======================

You are welcome to use this code for research purposes but it is not actively supported. 

Here are some pointers on getting it to work:

You will need to compile the rock first. In the file spectralnet-scm-1.rockspec, change the line
url = "..." --TODO
to url = "."
or url = "/path/to/spectral-lib"

Then run:

luarocks install spectralnet-scm-1.rockspec

To run on MNIST/CIFAR, download the datasets and change the paths in test/datasource.lua

You can get the datasets here:

https://github.com/torch/tutorials/tree/master/A_datasets

There are Matlab scripts with examples how to build the graphs in mresgraph. 

To train the models, run test/train.lua. The hyperparameters are in params.lua. 

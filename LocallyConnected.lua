local LocallyConnected, parent = torch.class('nn.LocallyConnected', 'nn.Module')

function LocallyConnected:__init(inputSize, outputSize, connTable)
   parent.__init(self)

   assert(outputSize == connTable:size(1))
   assert(inputSize == connTable:size(2))
   self.connTable = connTable
   self.weight = torch.Tensor(outputSize, inputSize)
   self.bias = torch.Tensor(outputSize)
   self.gradWeight = torch.Tensor(outputSize, inputSize)
   self.gradBias = torch.Tensor(outputSize)
   
   self:reset()
end

function LocallyConnected:reset(stdv)
   for i = 1,self.weight:size(1) do 
      local nInputs = self.connTable[i]:sum()
      stdv = 1./math.sqrt(nInputs)
      self.weight[i]:uniform(-stdv,stdv)
      self.bias[i]:uniform(-stdv,stdv)
   end
end

function LocallyConnected:updateOutput(input)
   self.weight:cmul(self.connTable)
   if input:dim() == 1 then
      self.output:resize(self.bias:size(1))
      self.output:copy(self.bias)
      self.output:addmv(1, self.weight, input)
   elseif input:dim() == 2 then
      local nframe = input:size(1)
      local nunit = self.bias:size(1)
      self.output:resize(nframe, nunit)
      if not self.addBuffer or self.addBuffer:size(1) ~= nframe then
         self.addBuffer = input.new(nframe):fill(1)
      end
      if nunit == 1 then
         -- Special case to fix output size of 1 bug:
         self.output:copy(self.bias:view(1,nunit):expand(#self.output))
         self.output:select(2,1):addmv(1, input, self.weight:select(1,1))
      else
         self.output:zero():addr(1, self.addBuffer, self.bias)
         self.output:addmm(1, input, self.weight:t())
      end
   else
      error('input must be vector or matrix')
   end

   return self.output
end

function LocallyConnected:updateGradInput(input, gradOutput)
   self.weight:cmul(self.connTable)
   if self.gradInput then

      local nElement = self.gradInput:nElement()
      self.gradInput:resizeAs(input)
      if self.gradInput:nElement() ~= nElement then
         self.gradInput:zero()
      end
      if input:dim() == 1 then
         self.gradInput:addmv(0, 1, self.weight:t(), gradOutput)
      elseif input:dim() == 2 then
         self.gradInput:addmm(0, 1, gradOutput, self.weight)
      end

      return self.gradInput
   end
end

function LocallyConnected:accGradParameters(input, gradOutput, scale)
   scale = scale or 1

   if input:dim() == 1 then
      self.gradWeight:addr(scale, gradOutput, input)
      self.gradBias:add(scale, gradOutput)
   elseif input:dim() == 2 then
      local nframe = input:size(1)
      local nunit = self.bias:size(1)

      if nunit == 1 then
         -- Special case to fix output size of 1 bug:
         self.gradWeight:select(1,1):addmv(scale, input:t(), gradOutput:select(2,1))
         self.gradBias:addmv(scale, gradOutput:t(), self.addBuffer)
      else
         self.gradWeight:addmm(scale, gradOutput:t(), input)
         self.gradBias:addmv(scale, gradOutput:t(), self.addBuffer)
      end
   end
   self.gradWeight:cmul(self.connTable)

end

-- we do not need to accumulate parameters when sharing
LocallyConnected.sharedAccUpdateGradParameters = LocallyConnected.accUpdateGradParameters


function LocallyConnected:__tostring__()
  return torch.type(self) ..
      string.format('(%d -> %d)', self.weight:size(2), self.weight:size(1))
end

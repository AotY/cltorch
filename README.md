# clnn
Experimental opencl module for torch

## Things that are working

<table>

<tr><td>Component<td>Status<td>Examples of what works now</tr>

<tr><td><pre>require 'clnn'</pre> <td> works <td><pre>require 'clnn'</pre></tr>

<tr><td>Device information<td>works<td><pre>
print('num devices:', clnn.getDeviceCount())
props = clnn.getDeviceProperties(1)
</pre></tr>

<tr><td> torch.ClStorage <td> works <td><pre>
c = torch.ClStorage()
c = torch.ClStorage(3)
c[1] = 5
c = torch.ClStorage{4,9,2}
c:fill(7)
a = torch.Storage{1.5, 2.4, 5.3}
c:copy(a)
c[2] = 21
a:copy(c)
d = torch.ClStorage(3)
d:copy(c)
</pre></tr>

<tr><td>conversion to/from ClTensor <td>works<td><pre>
c = torch.ClTensor{7,4,5}
c = torch.ClTensor(3,2)
c = torch.Tensor{2,6,9}:cl()
b = c:float()
c = torch.ClTensor{{3,1,6},{2.1,5.2,3.9}}
b:copy(c)
c:copy(b)
d = torch.ClTensor(2,3)
d:copy(c)
c[1][2] = 2.123
</pre></tr>

<tr><td>Element-wise operations<td>Done<td><pre>
c:abs()
for _,name in ipairs({'log','exp', 'cos', 'acos', 'sin', 'asin',
   'atan', 'tanh', 'ceil', 'floor', 'abs', 'round'}) do
  loadstring('c:' .. name .. '()')()
end
</pre>
</tr>

<tr><td>basic operations <td>30% done<td><pre>
d = torch.ClTensor{{3,5,-2},{2.1,2.2,3.9}}
c = torch.ClTensor{{4,2,-1},{3.1,1.2,4.9}}
c:add(d)
c:cmul(d)
c:cdiv(d)
for _,name in ipairs({'lt','le','gt','ge','ne','eq'}) do
  print(loadstring('return torch.' .. name .. '(c,d)')())
end
c:add(3)
c:mul(3)
c:div(2)
c = torch.add(c,3)
c = torch.mul(c, 4)
c = torch.div(c, 3)
for _,name in ipairs({'lt','le','gt','ge','ne','eq'}) do
  print(loadstring('return c:' .. name .. '(5)')())
end
torch.pow(2,c)
c:pow(2)
torch.cpow(c,d)
torch.cdiv(c,d)
torch.pow(c,2)
torch.clamp(c, 50, 100)
c:clamp(50, 100)
-c

A = torch.ClTensor{{1,2,-1},
                   {3,4,0}}
B = torch.ClTensor{{0,1},
                   {1,2},
                   {4,5}}
print(torch.mm(A,B))
C:mm(A,B)
</pre></tr>

<tr><td>Overloaded operators <td>70% done (no matrix/vector multiplication yet)<td><pre>
c = c + d
c = c - d
c = c / 2
c = c * 1.5
c = c + 4
c = c - 5
</pre></tr>

</table>

# Migration status by file

By comparison with cutorch (and cunn etc) files.  Note that `.cpp` here could have been ported from `.c`, `.cpp`, or `.cu`.

| File | Migration status |
|---|---|
| THClTensorMathCompare.cpp | Done |
| THClTensormathCompareT.cpp | Done |
| THClTensorMathPairwise.cpp | Done |
| THClTensor.h | Done |
| THClTensorCopy.h | Done |
| THClTensorMath.h | Done |
| THClTensor.cpp | 90% |
| THClTensorCopy.cpp | 50% |
| THClTensorMath.cpp | 5% |
| THClTensorIndex.cpp | 0% |
| THClTensorMath2.cpp | 20% |
| THClTensorMathBlas.cpp | 25% |
| THClBlas.cpp | 33% |



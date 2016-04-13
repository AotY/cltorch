local wrap = require 'cwrap'

local interface = wrap.CInterface.new()
local method = wrap.CInterface.new()

interface:print('/* WARNING: autogenerated file */')
interface:print('')
interface:print('#include "THCl.h"')
interface:print('#include "THClTensor.h"')
interface:print('#include "THClTensorSort.h"')
interface:print('#include "THClStorage.h"')
interface:print('#include "luaT.h"')
interface:print('#include "torch/utils.h"')
interface:print('')
interface:print('')

-- specific to CL
local typename = 'ClTensor'

-- Lua 5.2 compatibility
local unpack = unpack or table.unpack

-- cut and paste from wrap/types.lua
wrap.types.ClTensor = {
   
   helpname = function(arg)
      if arg.dim then
         return string.format('%s~%dD', typename, arg.dim)
      else
         return typename
      end
   end,
   
   declare = function(arg)
      local txt = {}
      table.insert(txt, string.format("TH%s *arg%d = NULL;", typename, arg.i))
      if arg.returned then
         table.insert(txt, string.format("int arg%d_idx = 0;", arg.i));
      end
      return table.concat(txt, '\n')
   end,
   
   check = function(arg, idx)
      if arg.dim then
         return string.format('(arg%d = luaT_toudata(L, %d, "torch.%s")) && (arg%d->nDimension == %d)', arg.i, idx, typename, arg.i, arg.dim)
      else
         return string.format('(arg%d = luaT_toudata(L, %d, "torch.%s"))', arg.i, idx, typename)
      end
   end,
   
   read = function(arg, idx)
      if arg.returned then
         return string.format("arg%d_idx = %d;", arg.i, idx)
      end
   end,
   
   init = function(arg)
      if type(arg.default) == 'boolean' then
         local txt = {}
         table.insert(txt, string.format('int device%d = -1;', arg.i))
         for _,v in ipairs(arg.args) do
            --           print('i', v.i)
            --           for k,v in pairs(v) do
            --             print('   ', k, v)
            --           end
            if v.name == 'ClTensor' and v.i ~= arg.i then
               --             print('     init arg', v.i, v, v.name)
               table.insert(txt, string.format('if(arg%d != 0 && arg%d->storage != 0) { device%d = arg%d->device; }', v.i, v.i, arg.i, v.i))
            end
         end
         table.insert(txt, string.format('if(device%d == -1){ device%d = cltorch_getstate(L)->currentDevice; }', arg.i, arg.i))
         table.insert(txt, string.format('arg%d = TH%s_newv2(cltorch_getstate(L), device%d);', arg.i, typename, arg.i))
         return table.concat(txt, '\n')
      elseif type(arg.default) == 'number' then
         return string.format('arg%d = %s;', arg.i, arg.args[arg.default]:carg())
      else
         error('unknown default tensor type value')
      end
   end,
   
   carg = function(arg)
      return string.format('arg%d', arg.i)
   end,
   
   creturn = function(arg)
      return string.format('arg%d', arg.i)
   end,
   
   precall = function(arg)
      local txt = {}
      if arg.default and arg.returned then
         table.insert(txt, string.format('if(arg%d_idx)', arg.i)) -- means it was passed as arg
         table.insert(txt, string.format('lua_pushvalue(L, arg%d_idx);', arg.i))
         table.insert(txt, string.format('else'))
         if type(arg.default) == 'boolean' then -- boolean: we did a new()
            table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.%s");', arg.i, typename))
         else  -- otherwise: point on default tensor --> retain
            table.insert(txt, string.format('{'))
               table.insert(txt, string.format('TH%s_retain(arg%d);', typename, arg.i)) -- so we need a retain
               table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.%s");', arg.i, typename))
               table.insert(txt, string.format('}'))
         end
      elseif arg.default then
         -- we would have to deallocate the beast later if we did a new
         -- unlikely anyways, so i do not support it for now
         if type(arg.default) == 'boolean' then
            error('a tensor cannot be optional if not returned')
         end
      elseif arg.returned then
         table.insert(txt, string.format('lua_pushvalue(L, arg%d_idx);', arg.i))
      end
      return table.concat(txt, '\n')
   end,
   
   postcall = function(arg)
      local txt = {}
      if arg.creturned then
         -- if a tensor is returned by a wrapped C function, the refcount semantics
         -- are ambiguous (transfer ownership vs. shared ownership).
         -- We never actually do this, so lets just not allow it.
         error('a tensor cannot be creturned')
      end
      return table.concat(txt, '\n')
   end
}

wrap.types.string = {
   
   helpname = function(arg)
      return "string"
   end,
   
   declare = function(arg)
      -- if it is a number we initialize here
      --                local default = interpretdefaultvalue(arg) or ''
      local default = ''
      print('default', default)
      return string.format("char const* arg%d = \"%s\";", arg.i, default)
   end,
   
   check = function(arg, idx)
      return string.format("lua_isstring(L, %d)", idx)
   end,
   
   read = function(arg, idx)
      return string.format("arg%d = lua_tostring(L, %d);", arg.i, idx)
   end,
   
   init = function(arg)
      -- otherwise do it here
      if arg.default then
         --                local default = interpretdefaultvalue(arg)
         if not default then
            return string.format("arg%d = \"%s\";", arg.i, default)
         end
      end
   end,
   
   carg = function(arg)
      return string.format('arg%d', arg.i)
   end,
   
   creturn = function(arg)
      return string.format('arg%d', arg.i)
   end,
   
   precall = function(arg)
      if arg.returned then
         return string.format('lua_pushstring(L, arg%d);', arg.i)
      end
   end,
   
   postcall = function(arg)
      if arg.creturned then
         return string.format('lua_pushstring(L, arg%d);', arg.i)
      end
   end
}

wrap.types.LongArg = {
   
   vararg = true,
   
   helpname = function(arg)
      return "(LongStorage | dim1 [dim2...])"
   end,
   
   declare = function(arg)
      return string.format("THLongStorage *arg%d = NULL;", arg.i)
   end,
   
   init = function(arg)
      if arg.default then
         error('LongArg cannot have a default value')
      end
   end,
   
   check = function(arg, idx)
      return string.format("cltorch_islongargs(L, %d)", idx)
   end,
   
   read = function(arg, idx)
      return string.format("arg%d = cltorch_checklongargs(L, %d);", arg.i, idx)
   end,
   
   carg = function(arg, idx)
      return string.format('arg%d', arg.i)
   end,
   
   creturn = function(arg, idx)
      return string.format('arg%d', arg.i)
   end,
   
   precall = function(arg)
      local txt = {}
      if arg.returned then
         table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.LongStorage");', arg.i))
      end
      return table.concat(txt, '\n')
   end,
   
   postcall = function(arg)
      local txt = {}
      if arg.creturned then
         -- this next line is actually debatable
         table.insert(txt, string.format('THLongStorage_retain(arg%d);', arg.i))
         table.insert(txt, string.format('luaT_pushudata(L, arg%d, "torch.LongStorage");', arg.i))
      end
      if not arg.returned and not arg.creturned then
         table.insert(txt, string.format('THLongStorage_free(arg%d);', arg.i))
      end
      return table.concat(txt, '\n')
   end
}

function interface.luaname2wrapname(self, name)
   return string.format('cltorch_ClTensor_%s', name)
end

local function cname(name)
   return string.format('THClTensor_%s', name)
end

local function lastdim(argn)
   return function(arg)
      return string.format("THClTensor_nDimension(cltorch_getstate(L), %s)", arg.args[argn]:carg())
   end
end

cltorch_state_code = function(varname)
   local txt = {}
   table.insert(txt, 'lua_getglobal(L, "cltorch");')
   table.insert(txt, 'lua_getfield(L, -1, "_state");')
   table.insert(txt, string.format('THClState *%s = lua_touserdata(L, -1);', varname))
   table.insert(txt, 'lua_pop(L, 2);')
   return table.concat(txt, '\n');
end
interface:registerDefaultArgument(cltorch_state_code)
method:registerDefaultArgument(cltorch_state_code)

local function wrap(...)
   local args = {...}
   
   -- interface
   interface:wrap(...)
   
   -- method: we override things possibly in method table field
   for _,x in ipairs(args) do
      if type(x) == 'table' then -- ok, now we have a list of args
         for _, arg in ipairs(x) do
            if arg.method then
               for k,v in pairs(arg.method) do
                  if v == 'nil' then -- special case, we erase the field
                     arg[k] = nil
                  else
                     arg[k] = v
                  end
               end
            end
         end
      end
   end
   method:wrap(unpack(args))
end

local Tensor = "ClTensor"
local real = "float"

wrap("apply",
   cname("apply"),
   {{name=Tensor, returned=true},
      {name="string"}})

wrap("map",
   cname("map"),
   {{name=Tensor, returned=true},
      {name=Tensor},
      {name="string"}})

wrap("map2",
   cname("map2"),
   {{name=Tensor, returned=true},
      {name=Tensor},
      {name=Tensor},
      {name="string"}})

wrap("apply2",
   cname("map"),
   {{name=Tensor, returned=true},
      {name=Tensor},
      {name="string"}})

wrap("apply3",
   cname("map2"),
   {{name=Tensor, returned=true},
      {name=Tensor},
      {name=Tensor},
      {name="string"}})

wrap("zero",
   cname("zero"),
   {{name=Tensor, returned=true}})

wrap("fill",
   cname("fill"),
   {{name=Tensor, returned=true},
      {name=real}},
   cname("fill_gpu"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor}})

wrap("zeros",
   cname("zeros"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name="LongArg"}})

wrap("ones",
   cname("ones"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name="LongArg"}})

wrap("reshape",
   cname("reshape"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor},
      {name="LongArg"}})

wrap("numel",
   cname("numel"),
   {{name=Tensor},
      {name="long", creturned=true}})

wrap("add",
   cname("add"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real}},
   --     cname("add_gpu"),
   --     {{name=Tensor, default=true, returned=true, method={default='nil'}},
   --        {name=Tensor, method={default=1}},
   --        {name=Tensor}},
   cname("cadd"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real, default=1},
      {name=Tensor}})

wrap("csub",
   cname("sub"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real}},
   --     cname("sub_gpu"),
   --     {{name=Tensor, default=true, returned=true, method={default='nil'}},
   --        {name=Tensor, method={default=1}},
   --        {name=Tensor}},
   cname("csub"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real, default=1},
      {name=Tensor}})

wrap("mul",
   cname("mul"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real}},
   cname("mul_gpu"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=Tensor}})

wrap("gather",
   cname("gather"),
   {{name=Tensor, default=true, returned=true,
         init=function(arg)
            return table.concat(
               {
                  string.format('THClState *state = cltorch_getstate(L);'),
                  string.format('THLongStorage *%s_newSize = THLongStorage_newWithSize(%s->nDimension);', arg:carg(), arg.args[4]:carg()),
                  string.format('THLongStorage_rawCopy(%s_newSize, %s->size);', arg:carg(), arg.args[4]:carg()),
                  string.format('%s = THClTensor_newv2(state, %s->storage->device);', arg:carg(), arg.args[4]:carg()),
                  string.format('THClTensor_resize(state, %s, %s_newSize, NULL);', arg:carg(), arg:carg()),
                  string.format('THLongStorage_free(%s_newSize);', arg:carg()),
            }, '\n')
         end
      },
      {name=Tensor},
      {name="index"},
      {name=Tensor, noreadadd=true}
})

wrap("scatter",
   cname("scatter"),
   {{name=Tensor, returned=true},
      {name="index"},
      {name=Tensor, noreadadd=true},
      {name=Tensor}},
   cname("scatterFill"),
   {{name=Tensor, returned=true},
      {name="index"},
      {name=Tensor, noreadadd=true},
      {name=real}})

wrap("div",
   cname("div"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real}},
   cname("div_gpu"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=Tensor}}
)

for _, name in ipairs({"cmul", "cpow", "cdiv"}) do
   wrap(name,
      cname(name),
      {{name=Tensor, default=true, returned=true, method={default='nil'}},
         {name=Tensor, method={default=1}},
         {name=Tensor}})
end

wrap("addcmul",
   cname("addcmul"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real, default=1},
      {name=Tensor},
      {name=Tensor}})

wrap("addcdiv",
   cname("addcdiv"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real, default=1},
      {name=Tensor},
      {name=Tensor}})

wrap("maskedFill",
   cname("maskedFill"),
   {{name=Tensor, returned=true, method={default='nil'}},
      {name=Tensor},
      {name=real}})

wrap("maskedCopy",
   cname("maskedCopy"),
   {{name=Tensor, returned=true, method={default='nil'}},
      {name=Tensor},
      {name=Tensor}})

wrap("maskedSelect",
   cname("maskedSelect"),
   {{name=Tensor, returned=true, default=true},
      {name=Tensor},
      {name=Tensor}})

wrap("sort",
     cname("sort"),
     {{name=Tensor, default=true, returned=true},
        {name=Tensor, default=true, returned=true, noreadadd=true},
        {name=Tensor},
        {name="index", default=lastdim(3)},
        {name="boolean", default=0}})


do
   local Tensor = Tensor
   local real = real
   wrap("mv",
      cname("addmv"),
      {{name=Tensor, default=true, returned=true, method={default='nil'},
            init=function(arg)
               return table.concat(
                  {
                     arg.__metatable.init(arg),
                     string.format("TH%s_checkGPU(cltorch_getstate(L), 1, %s);",
                        Tensor, arg.args[5]:carg()),
                     string.format("TH%s_resize1d(cltorch_getstate(L), %s, %s->size[0]);", Tensor, arg:carg(), arg.args[5]:carg())
               }, '\n')
            end,
            precall=function(arg)
               return table.concat(
                  {
                     string.format("TH%s_zero(cltorch_getstate(L), %s);", Tensor, arg:carg()),
                     arg.__metatable.precall(arg)
               }, '\n')
            end
         },
         {name=real, default=1, invisible=true},
         {name=Tensor, default=1, invisible=true},
         {name=real, default=1, invisible=true},
         {name=Tensor, dim=2},
         {name=Tensor, dim=1}}
   )
   
   wrap("mm",
      cname("addmm"),
      {{name=Tensor, default=true, returned=true, method={default='nil'},
            init=function(arg)
               return table.concat(
                  {
                     arg.__metatable.init(arg),
                     string.format("TH%s_checkGPU(cltorch_getstate(L), 2, %s, %s);",
                        Tensor, arg.args[5]:carg(), arg.args[6]:carg()),
                     string.format("TH%s_resize2d(cltorch_getstate(L), %s, %s->size[0], %s->size[1]);",
                        Tensor, arg:carg(), arg.args[5]:carg(), arg.args[6]:carg())
               }, '\n')
            end,
         },
         {name=real, default=0, invisible=true},
         {name=Tensor, default=1, invisible=true},
         {name=real, default=1, invisible=true},
         {name=Tensor, dim=2},
         {name=Tensor, dim=2}}
   )
   
   wrap("bmm",
      cname("baddbmm"),
      {{name=Tensor, default=true, returned=true, method={default='nil'},
            init=function(arg)
               return table.concat(
                  {
                     arg.__metatable.init(arg),
                     string.format("TH%s_checkGPU(cltorch_getstate(L), 2, %s, %s);",
                        Tensor, arg.args[5]:carg(), arg.args[6]:carg()),
                     string.format("TH%s_resize3d(cltorch_getstate(L), %s, %s->size[0], %s->size[1], %s->size[2]);",
                        Tensor, arg:carg(), arg.args[5]:carg(), arg.args[5]:carg(), arg.args[6]:carg())
               }, '\n')
            end,
         },
         {name=real, default=0, invisible=true},
         {name=Tensor, default=1, invisible=true},
         {name=real, default=1, invisible=true},
         {name=Tensor, dim=3},
         {name=Tensor, dim=3}}
   )
   
   wrap("ger",
      cname("addr"),
      {{name=Tensor, default=true, returned=true, method={default='nil'},
            init=function(arg)
               return table.concat(
                  {
                     arg.__metatable.init(arg),
                     string.format("TH%s_checkGPU(cltorch_getstate(L), 2, %s, %s);",
                        Tensor, arg.args[5]:carg(), arg.args[6]:carg()),
                     string.format("TH%s_resize2d(cltorch_getstate(L), %s, %s->size[0], %s->size[0]);", Tensor, arg:carg(), arg.args[5]:carg(), arg.args[6]:carg())
               }, '\n')
            end,
            precall=function(arg)
               return table.concat(
                  {
                     string.format("TH%s_zero(cltorch_getstate(L), %s);", Tensor, arg:carg()),
                     arg.__metatable.precall(arg)
               }, '\n')
            end
         },
         {name=real, default=1, invisible=true},
         {name=Tensor, default=1, invisible=true},
         {name=real, default=1, invisible=true},
         {name=Tensor, dim=1},
         {name=Tensor, dim=1}}
   )
   
   for _,f in ipairs({
         {name="addmv",   dim1=1, dim2=2, dim3=1},
         {name="addmm",   dim1=2, dim2=2, dim3=2},
         {name="addr",    dim1=2, dim2=1, dim3=1},
         {name="baddbmm", dim1=3, dim2=3, dim3=3},
      }
      ) do
      
      interface:wrap(f.name,
         cname(f.name),
         {{name=Tensor, default=true, returned=true},
            {name=real, default=1},
            {name=Tensor, dim=f.dim1},
            {name=real, default=1},
            {name=Tensor, dim=f.dim2},
            {name=Tensor, dim=f.dim3}})
      
      -- there is an ambiguity here, hence the more complicated setup
      method:wrap(f.name,
         cname(f.name),
         {{name=Tensor, returned=true, dim=f.dim1},
            {name=real, default=1, invisible=true},
            {name=Tensor, default=1, dim=f.dim1},
            {name=real, default=1},
            {name=Tensor, dim=f.dim2},
            {name=Tensor, dim=f.dim3}},
         cname(f.name),
         {{name=Tensor, returned=true, dim=f.dim1},
            {name=real},
            {name=Tensor, default=1, dim=f.dim1},
            {name=real},
            {name=Tensor, dim=f.dim2},
            {name=Tensor, dim=f.dim3}})
   end
end

wrap("dot",
   cname("dot"),
   {{name=Tensor},
      {name=Tensor},
      {name=real, creturned=true}})

wrap("s",
   cname("as_float"),
   {{name=Tensor},
      {name=real, creturned=true}})

wrap("sum",
   cname("sumall"),
   {{name=Tensor},
      {name=real, creturned=true}},
   cname("sumall_gpu"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor}},
   cname("sum"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor},
      {name="index"}})

for _, name in ipairs({"cumsum", "cumprod"}) do
   wrap(name,
      cname(name),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor},
         {name="index", default=1}})
end

wrap("prod",
   cname("prodall"),
   {{name=Tensor},
      {name=real, creturned=true}},
   cname("prodall_gpu"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor}},
   cname("prod"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor},
      {name="index"}})

for _,name in ipairs({"min", "max"}) do
   wrap(name,
      cname(name .. "all"),
      {{name=Tensor},
         {name=real, creturned=true}},
      cname(name),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor, default=true, returned=true},
         {name=Tensor},
         {name="index"}},
      cname(name .. "all_gpu"),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor}})
end

for _,name in ipairs({"cmin", "cmax"}) do
   wrap(name,
      cname(name),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor, method={default=1}},
         {name=Tensor}},
      cname(name .. "Value"),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor, method={default=1}},
         {name=real}})
end

for _,name in ipairs({"log", "log1p", "exp",
      "cos", "acos", "cosh",
      "sin", "asin", "sinh",
      "tan", "atan", "tanh",
      "sqrt", "sigmoid",
      "ceil", "floor",
      "abs", "sign", "round", "neg", "cinv"}) do
   
   wrap(name,
      cname(name),
      {{name=Tensor, default=true, returned=true, method={default='nil'}},
         {name=Tensor, method={default=1}}})
   
end

wrap("atan2",
   cname("atan2"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=Tensor}}
)


wrap("pow",
   cname("pow"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real}},
   cname("tpow"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name = real},
      {name=Tensor, method={default=1}}})

wrap("rand",
   cname("rand"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name="LongArg"}})

wrap("randn",
   cname("randn"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name="LongArg"}})

wrap("clamp",
   cname("clamp"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, default=1},
      {name=real},
      {name=real}})

for _,name in pairs({'lt','gt','le','ge','eq','ne'}) do
   wrap(name,
      cname(name .. 'Value'),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor},
         {name=real}},
      cname(name .. 'Tensor'),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor},
         {name=Tensor}})
end

for _,name in pairs({'all', 'any'}) do
   wrap(name,
      cname('logical' .. name),
      {{name=Tensor},
         {name="boolean", creturned=true}},
      cname("logical" .. name .. "_gpu"),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor}})
end

--for _,f in ipairs({{name='geometric'},
--                   {name='bernoulli', a=0.5}}) do

--   wrap(f.name,
--        cname(f.name),
--        {{name=Tensor, returned=true},
--         {name=real, default=f.a}})
--end

--for _,f in ipairs({{name='uniform', a=0, b=1},
--                   {name='normal', a=0, b=1},
--                   {name='cauchy', a=0, b=1},
--                   {name='logNormal', a=1, b=2}}) do

--   wrap(f.name,
--        cname(f.name),
--        {{name=Tensor, returned=true},
--         {name=real, default=f.a},
--         {name=real, default=f.b}})
--end

--for _,f in ipairs({{name='exponential'}}) do

--   wrap(f.name,
--        cname(f.name),
--        {{name=Tensor, returned=true},
--         {name=real, default=f.a}})
--end


wrap("mean",
   cname("meanall"),
   {{name=Tensor},
      {name=real, creturned=true}},
   cname("mean"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor},
      {name="index"}})

for _,name in ipairs({"var", "std"}) do
   wrap(name,
      cname(name .. "all"),
      {{name=Tensor},
         {name=real, creturned=true}},
      cname(name),
      {{name=Tensor, default=true, returned=true},
         {name=Tensor},
         {name="index"},
         {name="boolean", default=false}})
end

wrap("norm",
   cname("normall"),
   {{name=Tensor},
      {name=real, default=2},
      {name=real, creturned=true}},
   cname("norm"),
   {{name=Tensor, default=true, returned=true},
      {name=Tensor},
      {name=real},
      {name="index"}})

wrap("renorm",
   cname("renorm"),
   {{name=Tensor, default=true, returned=true, method={default='nil'}},
      {name=Tensor, method={default=1}},
      {name=real},
      {name="index"},
      {name=real}})

wrap("dist",
   cname("dist"),
   {{name=Tensor},
      {name=Tensor},
      {name=real, default=2},
      {name=real, creturned=true}})

wrap("squeeze",
   cname("squeeze"),
   {{name=Tensor, default=true, returned=true, postcall=function(arg)
            local txt = {}
            if arg.returned then
               table.insert(txt, string.format('if(arg%d->nDimension == 1 && arg%d->size[0] == 1)', arg.i, arg.i)) -- number
               table.insert(txt, string.format('lua_pushnumber(L, (lua_Number)(THClTensor_get1d(cltorch_getstate(L), arg%d, 0)));', arg.i))
            end
            return table.concat(txt, '\n')
         end},
      {name=Tensor}},
   cname("squeeze1d"),
   {{name=Tensor, default=true, returned=true,
         postcall=
         function(arg)
            local txt = {}
            if arg.returned then
               table.insert(txt, string.format('if(!hasdims && arg%d->nDimension == 1 && arg%d->size[0] == 1)', arg.i, arg.i)) -- number
               table.insert(txt, string.format('lua_pushnumber(L, (lua_Number)(THClTensor_get1d(cltorch_getstate(L), arg%d, 0)));}', arg.i))
         end
         return table.concat(txt, '\n')
      end},
   
   {name=Tensor,
      precall=
      function(arg)
         return string.format('{int hasdims = arg%d->nDimension > 1;', arg.i)
         end},
      {name="index"}})

method:register("m_cltorch_ClTensorMath__")
interface:print(method:tostring())
method:clearhistory()
interface:register("cltorch_ClTensorMath__")

interface:print([[
   void cltorch_ClTensorMath_init(lua_State *L)
   {
   luaT_pushmetatable(L, "torch.ClTensor");
   
   /* register methods */
   luaL_setfuncs(L, m_cltorch_ClTensorMath__, 0);
   
   /* register functions into the "torch" field of the tensor metaclass */
   lua_pushstring(L, "torch");
   lua_newtable(L);
   luaL_setfuncs(L, cltorch_ClTensorMath__, 0);
   lua_rawset(L, -3);
   lua_pop(L, 1);
   }
]])

interface:tofile(arg[1])


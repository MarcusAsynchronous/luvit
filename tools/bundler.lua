--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local FS = require('fs')
local Path = require('path')
local Table = require('table')
local ChildProcess = require('childprocess')

local function map(array, fn)
  local new_array = {}
  for i,v in ipairs(array) do
    new_array[i] = fn(v, i, array)
  end
  return new_array
end

local function mapcat(array, fn, join)
  return Table.concat(map(array, fn), join or "")
end

local libdir = Path.join(Path.dirname(process.execPath), Path.join("..", "lib", "luvit"))

local files = FS.readdirSync(libdir)
local names = map(files, function (file)
  return file:match("^([^.]*)")
end)
Table.sort(names)

local exports_c = [[
/* This file is generated by bundler.lua */
#include <string.h>
#include "luvit.h"

const void *luvit_ugly_hack = NULL;

]] .. mapcat(names, function (name) return "extern const char *luaJIT_BC_" .. name .. "[];\n" end) .. [[
const void *luvit__suck_in_symbols(void)
{
  const char **luvit_ugly_hack[] =
  {
]] .. mapcat(names, function (name) return "    luaJIT_BC_" .. name end, ",\n") .. [[    0
  };

  return (const void *)&luvit_ugly_hack[0];
}
]]

local exports_h = [[
/* This file is generated by bundler.lua */
#ifndef LUV_EXPORTS
#define LUV_EXPORTS

const void *luvit__suck_in_symbols(void);

#endif
]]


FS.mkdir("bundle", "0755", function (err)
  if err then
    if not (err.code == "EEXIST") then error(err) end
  end
  local left = 0
  local function pend()
    left = left + 1
    return function (err)
      if err then error(err) end
      left = left - 1
      if left == 0 then
--        print("Done!")
      end
    end
  end

  FS.writeFile(Path.join("src", "luvit_exports.c"), exports_c, pend())
  FS.writeFile(Path.join("src", "luvit_exports.h"), exports_h, pend())
  for i, file in ipairs(files) do
    ChildProcess.execFile(Path.join("deps", "luajit", "src", "luajit"), {"-bg", Path.join("lib", "luvit", file), Path.join("bundle", names[i] .. ".c")}, {}, pend())
  end

end);

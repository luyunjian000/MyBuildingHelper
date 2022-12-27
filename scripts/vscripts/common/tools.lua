if Tools == nil then
  Tools = class({})
end

local find = string.find
local fmt = string.format
local cut = string.sub
local gmatch = string.gmatch
local error = error

function Tools:split(str, delimiter)
  -- Handle an edge case concerning the str parameter. Immediately return an
  -- empty table if str == ''.
  if str == '' then return {} end

  -- Handle special cases concerning the delimiter parameter.
  -- 1. If the pattern is nil, split on contiguous whitespace.
  -- 2. If the pattern is an empty string, explode the string.
  -- 3. Protect against patterns that match too much. Such patterns would hang
  --    the caller.
  delimiter = delimiter or '%s+'
  if delimiter == '' then return explode(str) end
  if find('', delimiter, 1) then
    local msg = fmt('The delimiter (%s) would match the empty string.',
                    delimiter)
    error(msg)
  end

  -- The table `t` will store the found items. `s` and `e` will keep
  -- track of the start and end of a match for the delimiter. Finally,
  -- `position` tracks where to start grabbing the next match.
  local t = {}
  local s, e
  local position = 1
  s, e = find(str, delimiter, position)

  while s do
    t[#t + 1] = cut(str, position, s-1)
    position = e + 1
    s, e = find(str, delimiter, position)
  end

  -- To get the (potential) last item, check if the final position is
  -- still within the string. If it is, grab the rest of the string into
  -- a final element.
  if position <= #str then
    t[#t + 1] = cut(str, position)
  end

  -- Special handling for a (potential) final trailing delimiter. If the
  -- last found end position is identical to the end of the whole string,
  -- then add a trailing empty field.
  if position > #str then
    t[#t + 1] = ''
  end

  return t
end

function explode(str)
  local t = {}
  for i=1, #str do
    t[#t + 1] = cut(str, i, i)
  end

  return t
end


-- 通用打印日志 数字好像有点问题
function Tools:CommonPrint(v, t)
  if TESTMODEL then
      if IsClient() then
          print("[客户端消息]")
      end

      if v == nil then
          v = "nil"
      end

      if t == nil then
          t = ""
      end

      if type(v) == "table" then
          if t ~= "" then
              print(t)
          end
          DeepPrintTable(v)
      else
          if t ~= "" then
              print('['..tostring(t)..']:'..tostring(v))
          else
              print(tostring(v))
          end
      end
  end
end
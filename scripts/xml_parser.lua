--This is a lua xml parsing module made to mimic the ElementTree module for Python3
--Made by Jaemspio (better known as the creator of this mod)
--This file will only work with lua debug enabled
--This file is not meant to be an api, has no docs, and was never meant to be used by anyone except me
--Yes, it is very stupid to write an xml parsing module entirely in lua, but I digress
--Yes, I could have just used Python, but I like lua leave me alone :(
--[[IMPORTANT / WARNING - This file is only made to be used by me (Jaemspio) and was writen entirely in spaghetti code
It is highly recommend that	you don't attempt to either use or read this file, as it will probably cause you to have an aneurism	]]
--Sincerely, James

local function split(t, a, b)
  b = b or #t
  if not a or a > b or b > #t then return {} end
  local ret = {}
  for i, j in pairs(t) do
	if type(i) == "number" and i >= a and i <= b then
	  ret[i] = j
	end
  end
  return ret
end

local function isEndLine(line)
  if line:find("</") and not line:find("<%w+") then
	return true
  end
  return false
end

function rawpairs(t) --Calls "pairs" without invoking the "__pairs" metatable method
  if type(t) ~= "table" then return end
  local meta = getmetatable(t)
  if not meta then return pairs(t) end
  local oldPairs = rawget(meta, "__pairs")
  if not oldPairs then return pairs(t) end
  rawset(meta, "__pairs", nil)
  local ret1, ret2, ret3 = pairs(t)
  rawset(meta, "__pairs", oldPairs)
  return ret1, ret2, ret3
end

local function getLines(str)
  local ret = {}
  for line in string.gmatch(str, "[^\n]+") do
	if (line:find("<%w+") or line:find("</%w+")) and line:find("%g") then
	  table.insert(ret, line)
	end
  end
  return ret
end

local function doesLineEnd(line)
  local node
  if isEndLine(line) then return 0 end
  do
	local start, en = line:find("<%w+")
	node = line:sub(start + 1, en)
  end
  do
	if line:find("<"..node) and line:find("/>") then
	  return 1
	elseif line:find("<"..node..">") and line:find("</"..node..">") then
	  return 2
	end
  end
  return nil
end

local function findLineEnd(file, lineNum, debug)
  if type(file) ~= "table" then return end
  local line = file[lineNum]
  if doesLineEnd(line) then return lineNum end
  local start, en = line:find("<%w+")
  local node = line:sub(start + 1, en)
  for i, j in pairs(file) do
	if i >= lineNum and j:find("</"..node..">") then
	  return i
	end
  end
  return lineNum
end

local function getSpaces(line)
  local a, b = line:find("%s+")
  if a == nil or a ~= 1 then return 0 end
  if a and b then return b end
  return 0
end

local function parseSingleLine(line, reason)
  reason = reason or 1
  local metaValues = {
	__newindex = function(self, key, value)
	  return nil
	end,
	__len = function(self)
	  return #self.attributes
	end,
	__pairs = function(self)
	  return pairs(self.attributes)
	end,
  }
  local list = {node = "", attributes = {}}
  list.get = function(self, what)
	return self.attributes[what]
  end
  if line:find("</") then
	list.node = line:match("%a+")
	return setmetatable(list, metaValues)
  end
  do
	local start, en = line:find("<%w+")
	if not start or not en then return end
	list.node = line:sub(start + 1, en)
  end
  do
	if line:find("<"..list.node..">") or line:find("<"..list.node.."/>") or line:find("</"..list.node) then
	  return setmetatable(list, metaValues)
	end
	if reason == 1 then
	  local _, start = line:find("<"..list.node)
	  local parse = line:sub(start + 1, line:find("/>") - 1)
	  local sta, en = parse:find("[%w_]+=")
	  while sta and en do
		list.attributes[parse:sub(sta, en - 1)] = parse:sub(en + 2, parse:find("\"", en + 2) - 1)
		sta, en = parse:find("[%w_]+=", en + 1)
	  end
	elseif reason == 2 then
	  local _, start = line:find("<"..list.node..">")
	  local en, _ = line:find("</"..list.node..">")
	  local parse = line:sub(start + 1, en - 1)
	  if tonumber(parse) then
		table.insert(list.attributes, tonumber(parse))
	  else
		table.insert(list.attributes, parse)
	  end
	elseif reason == 3 then
	  local _, start = line:find("<"..list.node)
	  local parse = line:sub(start + 1, line:find(">") - 1)
	  local sta, en = parse:find("[%w_]+=")
	  while sta and en do
		if parse:sub(en + 1, en + 3) == '""' then
		  list.attributes[parse:sub(sta, en - 1)] = nil
		else
		  list.attributes[parse:sub(sta, en - 1)] = parse:sub(en + 2, parse:find("\"", en + 2) - 1)
		  sta, en = parse:find("[%w_]+=", en + 1)
		end
	  end
	end
  end
  return setmetatable(list, metaValues)
end

local function parseLineInFile(file, lineNum)
  local metaValues = {
	__index = function(self, key)
	  if key ~= "children" then
		return rawget(self, key)
	  else
		return nil
	  end
	end,
	__newindex = function(self, key, value)
	  return nil
	end,
	__len = function(self)
	  return #self.children
	end,
	__pairs = function(self)
	  return pairs(self.children)
	end,
  }
  if type(file) ~= "table" then return end
  local line = file[lineNum]
  if doesLineEnd(line) then return parseSingleLine(line, doesLineEnd(line)) end
  local en = findLineEnd(file, lineNum)
  local list = debug.setmetatable(parseSingleLine(line, 3), nil)
  list.children = {}
  list.findAll = function(self, what)
	local t = {}
	for _, j in pairs(self.children) do
	  if j.node == what then
		table.insert(t, j)
	  end
	end
	local ret1, ret2, ret3 = pairs(t)
	return ret1, ret2, ret3
  end
  list.find = function(self, what)
	local ret
	for _, j in pairs(self.children) do
	  if j.node == what then
		ret = j
		break
	  end
	end
	return ret
  end
  local spaces = 999999
  for i, j in pairs(split(file, lineNum + 1, en - 1)) do
	if getSpaces(j) > getSpaces(line) then
	  spaces = math.min(spaces, getSpaces(j))
 	end
  end
  for i, j in pairs(split(file, lineNum + 1, en - 1)) do
	if getSpaces(j) == spaces and not isEndLine(j) then
	  if doesLineEnd(line) then
		table.insert(list.children, parseSingleLine(line, doesLineEnd(line)))
	  else
		table.insert(list.children, parseLineInFile(file, i))
	  end
	end
  end
  return setmetatable(list, metaValues)
end

local function readFile(self)
  local file = io.open(self.path, "r")
  file:seek("set", 0)
  local text = ""
  local line = file:read()
  while line ~= nil do
	text = text..line.."\n"
	line = file:read()
  end
  file:close()
  return text
end

local function findRoot(self)
  local file = getLines(readFile(self))
  local root = ""
  local num
  for i, line in pairs(file) do
	local _, start = line:find("<")
	if start and not (line:find("xml") and line:find("?")) then
	  root = line
	  num = i
	  break
	end
  end
  return parseLineInFile(file, num)
end

local function isFile(path)
  path = path or ""
  local file = io.open(path)
  return file ~= nil
end

local function isDirectory(path)
  path = path or ""
  local _, _, err = pcall(io.open, path)
  err = err or ""
  return string.find(err, "Permission denied") ~= nil --If the permission is denied, it means that this is a directory and not a file
end

local tab = {}
function tab.parse(self, path)
  local metaValues = {
	__newindex = function(self, key, value)
	  return nil
	end,
	__tostring = function(self)
	  return self.path or ""
	end,
  }
  local ret = {}
  ret.getRoot = findRoot
  if isFile(path) then
	ret.path = path
  else
	error("No file found called "..path, 2)
  end
  return setmetatable(ret, metaValues)
end

return tab

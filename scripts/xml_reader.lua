local function getFileLocation()
  local str = debug.getinfo(2, "S").source:sub(2)
  str = str:match("(.*/)")
  local start, _ = str:find("scripts")
  return str:sub(1, start - 1)
end

local function insert(str, s, pos)
  local first = str:sub(1, pos)
  local second = str:sub(pos + 1)
  str = first..s..second
  return str
end

local function isFile(path)
  path = path or ""
  local file = io.open(path)
  return file ~= nil
end

local function autoGenerateName(str)
  local _, start = str:find("Achievement_")
  str = str:sub(start + 1, -5)
  local i, j = str:sub(2):find("%u+")
  while i do
	if i == j then
	  str = insert(str, " ", i)
	  i, j = str:sub(2):find("%u+", i + 3)
	elseif i == j - 1 and str:sub(i + 1, i + 1) == "A" then --This line is specifically for "A Fetus In A Jar" 
	  str = insert(str, " ", i)
	  str = insert(str, " ", i + 2)
	  i, j = str:sub(2):find("%u+", i + 4)
	else
	  i, j = str:sub(2):find("%u+", j + 1)
	end
  end
  if str:sub(2):find("%d") and str:sub(1, 1) ~= "D" then
	local i = str:sub(2):find("%d")
	str = insert(str, " ", i)
  end
  return str
end

local function splitName(str)
  local i, j = str:sub(2):find("%u+")
  while i do
	if i == j then
	  str = insert(str, " ", i)
	  i, j = str:sub(2):find("%u+", i + 3)
	elseif i == j - 1 and str:sub(i + 1, i + 1) == "A" then
	  str = insert(str, " ", i)
	  str = insert(str, " ", i + 2)
	  i, j = str:sub(2):find("%u+", i + 4)
	else
	  i, j = str:sub(2):find("%u+", j + 1)
	end
  end
  if str:sub(2):find("%d") and str:sub(1, 1) ~= "D" then
	local i = str:sub(2):find("%d")
	str = insert(str, " ", i)
  end
  return str
end

local modPath = getFileLocation()
local xml = include("scripts/xml_parser")
local giantbook_xml = xml:parse("resources-dlc3/giantbook.xml"):getRoot()
local giantbooks = {}
for _, book in giantbook_xml:findAll("entry") do
  local gfxroot = giantbook_xml:get("anm2root")
  if not book:get("anm2") then break end --We have reached the end
  giantbooks[tonumber(book:get("id"))] = {Anm2 = gfxroot..book:get("anm2"), Anim = book:get("anim"), Gfx = gfxroot..book:get("gfx")}
end

local achievement_xml = xml:parse("resources-dlc3/achievements.xml"):getRoot()
local achievements = {}
local root
for _, paper in achievement_xml:findAll("achievement") do
  root = achievement_xml:get("gfxroot")
  achievements[tonumber(paper:get("id"))] = {Name = paper:get("steam_name"), Gfx = paper:get("gfx")}
end

local nightmares_xml = xml:parse("resources-dlc3/nightmares.xml"):getRoot()
local nightmares = {}
local background
for _, mare in pairs(nightmares_xml) do
  local gfxroot = nightmares_xml:get("root")
  background = gfxroot..nightmares_xml:get("backgroundAnm2")
  local base = ""
  if isFile("resources/"..gfxroot..mare:get("anm2")) then base = "resources/" else base = "resources-dlc3/" end
  local frame = xml:parse(base..gfxroot..mare:get("anm2")):getRoot():find("Animations"):find("Animation"):get("FrameNum") --Don't even try to comprehend this
  table.insert(nightmares, {Anm2 = gfxroot..mare:get("anm2"), Framecount = frame})
end

ScreenAPI:AddCallback(ModCallbacks.MC_EXECUTE_CMD, function(_, cmd)
  if cmd == "screen_write" then --Rewrites the "enums.lua" and "xml_data.lua" files to be updated with the lasted xml data
	do
	  local file = io.open(modPath.."xml_data.lua", "w") --Clears the file
	  file:flush()
	  file:close()
	end
	local file = io.open(modPath.."xml_data.lua", "a")
	file:write('--This file was auto-generated using "scripts/xml_reader.lua", and it contains data from in-game xml files\n')
	file:write("--This file will only need to be changed if the in-game xml files are updated, and mod should be mod updated shortly with the new data\n\n")
	file:write("local data = {}\n\n")
	do --giantbook.xml
	  file:write("data.Giantbooks = {\n")
	  for id, book in ipairs(giantbooks) do
		file:write("  ["..tostring(id).."] = {\""..book.Anm2.."\", \""..book.Anim.."\", \""..book.Gfx.."\"},\n")
	  end
	  file:write("}\n\n")
	end
	do --achievements.xml
	  file:write("--The first 178 achievements in this list had their names (the first field) auto-generated based on their png filepath\n")
	  file:write("data.Achievements = {\n")
	  for id, paper in ipairs(achievements) do
		if paper.Name then paper.Name = paper.Name:gsub("&apos;", "'") end
		file:write("  ["..tostring(id).."] = {")
		if not paper.Name then paper.Name = autoGenerateName(paper.Gfx) end
		if paper.Name:find("thelost") then paper.Name = "The Lost" end
		file:write("\""..paper.Name.."\", ")
		file:write("\""..root..paper.Gfx.."\"")
		file:write("},\n")
	  end
	  file:write("}\n\n")
	end
	do --nightmares.xml
	  file:write("data.NightmareBackground = \""..background.."\"\n")
	  file:write("data.Nightmares = {\n")
	  for id, mare in pairs(nightmares) do
		file:write("  ["..tostring(id).."] = {\""..mare.Anm2.."\", "..mare.Framecount.."},\n")
	  end
	  file:write("}\n\n")
	end
	file:write("return data\n")
	file:flush()
	file:close()
	do
	  do
		local file = io.open(modPath.."screen_enums.lua", "w")
		file:flush()
		file:close()
	  end
	  local file = io.open(modPath.."screen_enums.lua", "a")
	  file:write('--This file was auto-generated using "scripts/xml_reader.lua", and it contains data from in-game xml files\n')
	  file:write("--This file will only need to be changed if the in-game xml files are updated, and mod should be mod updated shortly with the new data\n\n")
	  file:write("--The names of the giantbook enums were derived from the names of their png files\n")
	  file:write("GiantbookType = {\n")
	  for id, book in ipairs(giantbooks) do
		if book.Anm2:find("GiantBook_") then
		  if book.Anm2:find("EternalHeart") then
			local _, start = book.Anim:find("_")
			local str
			if start then
			  str = book.Anim:sub(start + 1)
			else
			  str = "RedHeart"
			end
			str = splitName(str)
			str = str:gsub("%s", "_")
			file:write("  GIANTBOOK_"..str:upper().." = "..tostring(id)..",\n")
		  else
			local _, start = book.Anm2:find("GiantBook_")
			local str = book.Anm2:sub(start + 1, -6)
			str = str:gsub("_", "")
			str = splitName(str)
			str = str:gsub("%s", "_")
			file:write("  GIANTBOOK_"..str:upper().." = "..tostring(id)..",\n")
		  end
		else
		  local _, start = book.Gfx:find("_%a")
		  local str = book.Gfx:sub(start, -5)
		  if str:find("Rebirth") then str = str:sub(13) end
		  str = splitName(str)
		  str = str:gsub("%s", "_")
		  file:write("  GIANTBOOK_"..str:upper().." = "..tostring(id)..",\n")
		end
	  end
	  file:write("}\n\n")
	  file:write("AchievementType = {\n")
	  for id, paper in ipairs(achievements) do
		local str = paper.Name:gsub("%s", "_")
		str = str:gsub("'", "")
		str = str:gsub("%%", "")
		str = str:gsub("%.", "")
		str = str:gsub("!", "")
		str = str:gsub("?", "")
		str = str:gsub("+", "_plus")
		str = str:gsub("%-", "_")
		file:write("  ACHIEVEMENT_"..str:upper().." = "..id..",\n")
	  end
	  file:write("}\n")
	  file:flush()
	  file:close()
	end
	print("Data Updated!")
  end
end)

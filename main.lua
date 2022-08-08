if ScreenAPI then return end

ScreenAPI = RegisterMod("Screen Animations API", 1) --Some code was borrowed from AgentCucco, but was mainly written and made by me (Jaemspio)
local game = Game()
local sound = SFXManager()
local music = MusicManager()
local xmlData = include("xml_data")
local nullVector = Vector(0, 0)
local nightmare = Isaac.GetSoundIdByName("Nightmare Begin")
include("screen_enums")
if debug then include("scripts/xml_reader") end
local Queue = {}
local GiantbookAnim = Sprite()
GiantbookAnim.PlaybackSpeed = 0.5
local AchievementSpr = Sprite()
AchievementSpr:Load("gfx/ui/achievement/achievements.anm2", true)
AchievementSpr.PlaybackSpeed = 0.5
local BackgroundSpr = Sprite()
BackgroundSpr:Load(xmlData.NightmareBackground, true)
BackgroundSpr.PlaybackSpeed = 0.5
local NightmareSpr = Sprite()
NightmareSpr.PlaybackSpeed = 0.5
local CustomSpr = Sprite()
CustomSpr.PlaybackSpeed = 0.5
local Fade = Sprite()
Fade:Load("gfx/fade.anm2", true)
local CutsceneBack = Sprite()
CutsceneBack:Load("gfx/ui/cutscene/background.anm2", true)
CutsceneBack.PlaybackSpeed = 0.5
local CutsceneStr = Sprite()
CutsceneStr.PlaybackSpeed = 0.5
local CreditsSpr = Sprite()
CreditsSpr:Load("gfx/cutscenes/credits.anm2", true)
CreditsSpr.PlaybackSpeed = 0.5

local function GetScreenSize() -- By Kilburn himself.
  local room = game:GetRoom()
  local pos = Isaac.WorldToScreen(Vector(0, 0)) - room:GetRenderScrollOffset() - game.ScreenShakeOffset
  local rx = pos.X + 60 * 26 / 40
  local ry = pos.Y + 140 * (26 / 40)
  return rx * 2 + 13 * 26, ry * 2 + 7 * 26
end

local function doesSoundExist(id)
  local sfx = SFXManager()
  local ret = false
  sfx:Play(id)
  if sfx:IsPlaying(id) then ret = true end
  sfx:Stop(id)
  return ret
end

local function getMaxSoundID()
  local id = SoundEffect.NUM_SOUND_EFFECTS - 1
  local step = 32
  while step > 0 do
	if doesSoundExist(id + step) then
	  id = id + step
	else
	  step = step // 2
	end
  end
  return id
end

local function blacklist(entity)
  if entity:ToBomb() or entity:ToFamiliar() or entity:ToPickup() or entity:ToLaser() or entity:ToKnife() or entity:ToPlayer() or entity:ToProjectile() or entity:ToTear() then
	return true
  end
	return false
end

local OldTimer
local isPaused = false
local OverrideControls = false
local IsGamePaused
local loaded = false

local function FreezeGame(unfreeze)
  if unfreeze then
	OldTimer = nil
	isPaused = false
	for _, entity in pairs(Isaac.GetRoomEntities()) do
	  if entity:HasEntityFlags(EntityFlag.FLAG_FREEZE) and not blacklist(entity) then
		entity:ClearEntityFlags(EntityFlag.FLAG_FREEZE)
	  end
	end
	for p = 0, game:GetNumPlayers() - 1 do
	  local player = Isaac.GetPlayer(p)
	  local data = player:GetData()
	  player.ControlsEnabled = true
	end
  else
	isPaused = true
	if not OldTimer then
	  OldTimer = game.TimeCounter
	end
	for p = 0, game:GetNumPlayers() - 1 do
	  local player = Isaac.GetPlayer(p)
	  local data = player:GetData()
	  local sprite = player:GetSprite()
	  player.ControlsEnabled = false
	end
  end
end

--Start of Compatibility

do --Overwrites Game():IsPaused() to work with Custom Giantbooks/Achievements (yes, this is modifed code from resourses/scripts/main.lua)
  local meta = getmetatable(Game())
  local tab = {}
  local oldGamePaused = rawget(meta, "IsPaused")
  IsGamePaused = function()
	return oldGamePaused(Game())
  end
  function tab:IsPaused()
	if isPaused == true then
	  return true
	else
	  return oldGamePaused(Game())
	end
  end
  local oldIndex = meta.__index
  local newMeta = tab
  rawset(meta, "__index", function(self, k)
	return newMeta[k] or oldIndex(self, k)
  end)
end

--Returns the id of an Achievement based on it's "steam_name" field (or it's auto-generated name if it doesn't have one)
rawset(Isaac, "GetAchievementIdByName", function(name)
  for id, paper in pairs(xmlData.Achievements) do
	if paper[1] and paper[1] == name then
	  return id
	end
  end
  return -1
end)

function ScreenAPI.IsPlaying()
  return #Queue ~= 0 and not IsGamePaused()
end

--End of Compatibility

function ScreenAPI.PlayGiantbook(id, animName, player, config)
  if type(id) == "number" then
	if xmlData.Giantbooks[id] then
	  local book = xmlData.Giantbooks[id]
	  table.insert(Queue, {GfxRoot = book[3], Anm2 = book[1], Anim = book[2], Type = "Giantbook"})
	else
	  error("[Error] Invaild id: "..(id), 2)
	end
  elseif type(id) == "string" then
	table.insert(Queue, {GfxRoot = id, Anm2 = "gfx/ui/giantbook/giantbook.anm2", Anim = animName or "Appear", Type = "Giantbook"})
	if player and player:ToPlayer() and config then
	  player:GetData().GiantToAnimate = config
	end
  else
	error("[Error] Attempted to index an invaild type: "..type(id), 2)
  end
end

function ScreenAPI.PlayAchievement(id, duration)
  if type(id) == "number" then
	if xmlData.Achievements[id] then
	  local paper = xmlData.Achievements[id]
	  table.insert(Queue, {GfxRoot = paper[2], Duration = duration or 90, Type = "Achievement"})
	else
	  error("[Error] Invaild id: "..(id), 2)
	end
  elseif type(id) == "string" then
	table.insert(Queue, {GfxRoot = id, Duration = duration or 90, Type = "Achievement"})
  else
	error("[Error] Attempted to index an invaild type: "..type(id), 2)
  end
end

function ScreenAPI.PlayNightmare(id, canSkip)
  if canSkip == nil then canSkip = true end
  if type(id) == "number" then
	if xmlData.Nightmares[id] then
	  local list = xmlData.Nightmares[id]
	  table.insert(Queue, {Anm2 = list[1], Skip = canSkip, Frame = list[2], Type = "Nightmare"})
	else
	  error("[Error] Invaild id: "..(id), 2)
	end
  elseif type(id) == "string" then
	local dummy = Sprite()
	dummy:Load(id, true)
	dummy:SetFrame(dummy:GetDefaultAnimation(), 999999)
	table.insert(Queue, {Anm2 = id, Skip = canSkip, Frame = dummy:GetFrame(), Type = "Nightmare"})
  else
	error("[Error] Attempted to index an invaild type: "..type(id), 2)
  end
end

function ScreenAPI.PlayCutscene(anm2, sound, canSkip, credits, headShadow)
  if type(anm2) == "string" then
	Queue = {} --Empty the queue to give cutscenes priority
	local dummy = Sprite()
	dummy:Load(anm2, true)
	dummy:SetFrame(dummy:GetDefaultAnimation(), 999999)
	table.insert(Queue, {Anm2 = anm2, Frame = dummy:GetFrame() or 0, Sound = sound or 0, Skip = canSkip or true, Credits = credits or true, Shadow = headShadow or true, Type = "Cutscene"})
  else
	error("[Error] Attempted to index an invaild type: "..type(id), 2)
  end
end

function ScreenAPI.PlayCustomAnimation(anm2, anim, duration)
  if not anm2 or type(anm2) ~= "string" then return end
  local dummy = Sprite()
  dummy:Load(anm2, true)
  table.insert(Queue, {Anm2 = anm2, Anim = anim or dummy:GetDefaultAnimation(), Duration = duration, Type = "Custom"})
end

ScreenAPI:AddCallback(ModCallbacks.MC_INPUT_ACTION, function(_, player, hook, action)
  if not OverrideControls then return nil end
  if action >= ButtonAction.ACTION_BOMB and action <= ButtonAction.ACTION_MENUTAB and not (action == ButtonAction.ACTION_MENUCONFIRM and Queue[1].Skip) then
	return false
  end
end, InputHook.IS_ACTION_TRIGGERED)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
  if isPaused then
	if OldTimer then game.TimeCounter = OldTimer end
	for _, entity in pairs(Isaac.GetRoomEntities()) do
      if not entity:HasEntityFlags(EntityFlag.FLAG_FREEZE) and not blacklist(entity) then
		entity:AddEntityFlags(EntityFlag.FLAG_FREEZE)
      end
	end
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, npc)
  if isPaused then
	if not npc:ToPlayer() then
	  return false
	else
	  player:SetMinDamageCooldown(30) --All is fair, all is balanced
	  data.GiantDamageCooldown = 30
	end
  end
end)

local based = false

ScreenAPI:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
  local data = player:GetData()
  local sprite = player:GetSprite()
  if isPaused then
	if not data.GiantDamageCooldown then data.GiantDamageCooldown = player:GetDamageCooldown() end
	if not data.GiantToAnimate then
	  data.GiantFrame = data.GiantFrame or sprite:GetFrame()
	  data.GiantAnim = data.GiantAnim or sprite:GetAnimation()
	  data.GiantOFrame = data.GiantOFrame or sprite:GetOverlayFrame()
	  data.GiantOAnim = data.GiantOAnim or sprite:GetOverlayAnimation()
	  if data.GiantOAnim == "" then data.GiantOAnim = "HeadDown" end
	  if data.GiantOFrame < 1 then data.GiantOFrame = 1 end
	  sprite:SetFrame(data.GiantAnim, data.GiantFrame)
	  sprite:SetOverlayFrame(data.GiantOAnim, data.GiantOFrame)
	else
	  if data.GiantToAnimate and not based then
		based = true
		local Type = getmetatable(data.GiantToAnimate).__type
		if Type:find("Card") then
		  player:AnimateCard(data.GiantToAnimate.ID, "LiftItem")
		elseif Type:find("Item") then
		  player:AnimateCollectible(data.GiantToAnimate.ID, "LiftItem", "ShopIdle")
		end
	  end
	end
	player:SetMinDamageCooldown(data.GiantDamageCooldown)
	player.Velocity = Vector(0, 0)
  else
	data.GiantDamageCooldown = nil
	data.GiantFrame = nil
	data.GiantAnim = nil
	data.GiantOFrame = nil
	data.GiantOAnim = nil
	if not Queue[1] and data.GiantToAnimate then
	  local Type = getmetatable(data.GiantToAnimate).__type
	  if Type:find("Card") then
		player:AnimateCard(data.GiantToAnimate.ID, "HideItem")
	  elseif Type:find("Item") then
		player:AnimateCollectible(data.GiantToAnimate.ID, "HideItem", "ShopIdle")
	  end
	  data.GiantToAnimate = nil
	  based = false
	end
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, function(_, fam) --For freezing familiars
  local data = fam:GetData()
  local sprite = fam:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.GVelocity = fam.Velocity
	  data.GFrame = sprite:GetFrame()
	  data.GSpeed = fam.OrbitSpeed
	  data.isGiantFrozen = true
	end
	fam.Velocity = Vector(0, 0)
	fam.OrbitSpeed = 0
	sprite:SetFrame(data.GFrame)
  end
  if isPaused == false and data.isGiantFrozen then
	fam.Velocity = data.GVelocity
	fam.OrbitSpeed = data.GSpeed
	data.isGiantFrozen = nil
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_BOMB_UPDATE, function(_, bomb)
  local data = bomb:GetData()
  if isPaused then
	if not data.giantFrame or not data.giantVelocity then
	  data.giantFrame = bomb.FrameCount
	  data.giantVelocity = bomb.Velocity
	elseif data.giantFrame and data.giantVelocity then
	  bomb.Velocity = Vector(0, 0)
	  bomb:SetExplosionCountdown(45 - data.giantFrame)
	end
  elseif data.giantVelocity then
	bomb.Velocity = data.giantVelocity
	data.giantVelocity = nil
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_PROJECTILE_UPDATE, function(_, proj)
  local data = proj:GetData()
  local sprite = proj:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.GVelocity = proj.Velocity
	  data.GFallingSpeed = proj.FallingSpeed
	  data.GFallingAccel = proj.FallingAccel
	  data.GFrame = sprite:GetFrame()
	  data.isGiantFrozen = true
	end
	proj.Velocity = Vector(0, 0)
	proj.FallingSpeed = 0
	proj.FallingAccel = -0.1
	sprite:SetFrame(data.GFrame)
  end
  if isPaused == false and data.isGiantFrozen then
	proj.Velocity = data.GVelocity
	proj.FallingSpeed = data.GFallingSpeed
	proj.FallingAccel = data.GFallingAccel
	data.isGiantFrozen = nil
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, function(_, tear)
  local data = tear:GetData()
  local sprite = tear:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.Velocity = tear.Velocity
	  data.FallingSpeed = tear.FallingSpeed
	  data.FallingAcceleration = tear.FallingAcceleration
	  data.Frame = sprite:GetFrame()
	  data.isGiantFrozen = true
	end
	tear.Velocity = Vector(0, 0)
	tear.FallingSpeed = 0
	tear.FallingAcceleration = -0.1
	sprite:SetFrame(data.Frame)
  end
  if isPaused == false and data.isGiantFrozen then
	tear.Velocity = data.Velocity
	tear.FallingSpeed = data.FallingSpeed
	tear.FallingAcceleration = data.FallingAcceleration
	data.isGiantFrozen = nil
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, function(_, knife)
  local data = knife:GetData()
  local sprite = knife:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.GPosition = knife.Position
	  data.GRotation = knife.Rotation
	  data.GPathFollowSpeed = knife.PathFollowSpeed
	  data.GFrame = sprite:GetFrame()
	  data.isGiantFrozen = true
	end
	knife.Position = data.GPosition --Slightly scuffed, but I don't know how to change knife velocity
	knife.Rotation = data.GRotation
	knife:SetPathFollowSpeed(0)
	sprite:SetFrame(data.GFrame)
  end
  if isPaused == false and data.isGiantFrozen then
	knife:SetPathFollowSpeed(data.GPathFollowSpeed)
	data.isGiantFrozen = nil
  end
end)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, function(_, laser)
  local data = laser:GetData()
  local sprite = laser:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.GFrame = sprite:GetFrame()
	  data.isGiantFrozen = true
	end
	laser.Shrink = false
	sprite:SetFrame(data.GFrame)
  end
  if isPaused == false and data.isGiantFrozen then
	laser.Shrink = true
	data.isGiantFrozen = nil
  end
end)

local function genericFreeze(_, entity)
  local data = entity:GetData()
  local sprite = entity:GetSprite()
  if isPaused == true then
	if not data.isGiantFrozen then
	  data.GVelocity = entity.Velocity
	  data.GPosition = entity.Position --For entities that reject "velocity"
	  data.GFrame = sprite:GetFrame()
	  data.isGiantFrozen = true
	end
	entity.Velocity = Vector(0, 0)
	entity.Position = data.GPosition
	sprite:SetFrame(data.GFrame)
  end
  if isPaused == false and data.isGiantFrozen then
	entity.Velocity = data.GVelocity
	data.isGiantFrozen = nil
  end
end
ScreenAPI:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, genericFreeze)
ScreenAPI:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, genericFreeze)

ScreenAPI:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function()
  for _, entity in pairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
	local data = entity:GetData()
	local sprite = entity:GetSprite()
	if isPaused == true then
	  if not data.isGiantFrozen then
		data.GVelocity = entity.Velocity
		data.GPosition = entity.Position --For entities that reject "velocity"
		data.GFrame = sprite:GetFrame()
		data.isGiantFrozen = true
	  end
	  entity.Velocity = Vector(0, 0)
	  entity.Position = data.GPosition
	  sprite:SetFrame(data.GFrame)
	end
	if isPaused == false and data.isGiantFrozen then
	  entity.Velocity = data.GVelocity
	  data.isGiantFrozen = nil
	end
  end
end)

local frame = 0

ScreenAPI:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, function(_, shaderName)
  if (shaderName == 'ScreenAPIShader') and Queue[1] and Queue[1].Type == "Giantbook" then
	if not IsGamePaused() then
	  if (ModConfigMenu and ModConfigMenu.IsVisible) then
		ModConfigMenu.CloseConfigMenu()
	  end
	  if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then
		DeadSeaScrollsMenu:CloseMenu(true, true)
	  end
	  FreezeGame()
	  if not loaded then
		loaded = true
		GiantbookAnim:Load(Queue[1].Anm2, true)
	  end
	  if not OverrideControls then
		OverrideControls = true
		for p = 0, game:GetNumPlayers() - 1 do
		  local player = Isaac.GetPlayer(p)
		  local data = player:GetData()
		  if not data.GiantbookAPIControls then
			data.GiantbookAPIControls = player.Velocity
			player.ControlsEnabled = false
			player.Velocity = nullVector
		  end
		end
	  end
	  if not Queue[1].Appear then
		GiantbookAnim:Play(Queue[1].Anim, true)
		Queue[1].Appear = true
		if Queue[1].GfxRoot then
		  GiantbookAnim:ReplaceSpritesheet(0, Queue[1].GfxRoot)
		  GiantbookAnim:LoadGraphics()
		end
	  end
	  if GiantbookAnim:IsFinished(Queue[1].Anim) then
		table.remove(Queue, 1)
		loaded = false
		if (not Queue[1]) and OverrideControls then
		  OverrideControls = false
		  for p = 0, game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(p)
			local data = player:GetData()
			if data.GiantbookAPIControls then
			  player.ControlsEnabled = true
			  player.Velocity = data.GiantbookAPIControls
			  data.GiantbookAPIControls = nil
			end
		  end
		  FreezeGame(true)
		end
		return
	  end
	  local CenterX, CenterY = GetScreenSize()
	  GiantbookAnim:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
	  GiantbookAnim:Update()
	end
  elseif (shaderName == 'ScreenAPIShader') and Queue[1] and Queue[1].Type == "Achievement" then
	if not IsGamePaused() then
	  if (ModConfigMenu and ModConfigMenu.IsVisible) then
		ModConfigMenu.CloseConfigMenu()
	  end
	  if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then
		DeadSeaScrollsMenu:CloseMenu(true, true)
	  end
	  FreezeGame()
	  if not OverrideControls then
		OverrideControls = true
		for p = 0, game:GetNumPlayers() - 1 do
		  local player = Isaac.GetPlayer(p)
		  local data = player:GetData()

		  if not data.GiantbookAPIControls then
			data.GiantbookAPIControls = player.Velocity
			player.ControlsEnabled = false
			player.Velocity = nullVector
		  end
		end
	  end
	  if not Queue[1].Appear then
		AchievementSpr:Play("Appear", true)
		Queue[1].Appear = true
		if Queue[1].GfxRoot then
		  AchievementSpr:ReplaceSpritesheet(3, Queue[1].GfxRoot)
		  AchievementSpr:LoadGraphics()
		end
	  end
	  if AchievementSpr:IsFinished("Appear") then
		if not Queue[1].SoundPlayed then
		  sound:Play(SoundEffect.SOUND_BOOK_PAGE_TURN_12, 1, 0, false, 1)
		  Queue[1].SoundPlayed = true
		end
		if Queue[1].Duration <= 0 then
		  AchievementSpr:Play("Dissapear", true)
		else
		  Queue[1].Duration = Queue[1].Duration - 1
		end
	  end
	  if AchievementSpr:IsFinished("Dissapear") then
		table.remove(Queue, 1)
		if (not Queue[1]) and OverrideControls then
		  OverrideControls = false
		  for p = 0, game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(p)
			local data = player:GetData()
			if data.GiantbookAPIControls then
			  player.ControlsEnabled = true
			  player.Velocity = data.GiantbookAPIControls
			  data.GiantbookAPIControls = nil
			end
		  end
		  FreezeGame(true)
		end
		return nil
	  end
	local CenterX, CenterY = GetScreenSize()
	AchievementSpr:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
	AchievementSpr:Update()
	end
  elseif (shaderName == 'ScreenAPIShader') and Queue[1] and Queue[1].Type == "Nightmare" then
	if not IsGamePaused() then
	  if (ModConfigMenu and ModConfigMenu.IsVisible) then
		ModConfigMenu.CloseConfigMenu()
	  end
	  if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then
		DeadSeaScrollsMenu:CloseMenu(true, true)
	  end
	  local function endNightmare()
		table.remove(Queue, 1)
		loaded = false
		if (not Queue[1]) and OverrideControls then
		  OverrideControls = false
		  for p = 0, game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(p)
			local data = player:GetData()
			if data.GiantbookAPIControls then
			  player.ControlsEnabled = true
			  player.Velocity = data.GiantbookAPIControls
			  data.GiantbookAPIControls = nil
			end
		  end
		  FreezeGame(true)
		  music:Enable()
		  sound:Stop(nightmare)
		  game:Fadein(0.04)
		end
	  end
	  FreezeGame()
	  if not loaded then
		loaded = true
		NightmareSpr:Load(Queue[1].Anm2, true)
		Fade:Load("gfx/fade.anm2", true)
	  end
	  if not Queue[1].Appear then
		Queue[1].Appear = true
		BackgroundSpr:Play("Intro", true)
		sound:Play(nightmare, 2)
	  end
	  if not OverrideControls then
		OverrideControls = true
		music:Disable()
		for p = 0, game:GetNumPlayers() - 1 do
		  local player = Isaac.GetPlayer(p)
		  local data = player:GetData()
		  if not data.GiantbookAPIControls then
			data.GiantbookAPIControls = player.Velocity
			player.ControlsEnabled = false
			player.Velocity = nullVector
		  end
		end
	  end
	  if BackgroundSpr:IsFinished("Intro") then
		Queue[1].Ready = true
		BackgroundSpr:Play("Loop")
		NightmareSpr:Play(NightmareSpr:GetDefaultAnimation(), true)
	  end
	  if (NightmareSpr:IsFinished(NightmareSpr:GetDefaultAnimation()) or (Queue[1].Frame and NightmareSpr:GetFrame() + 15 >= Queue[1].Frame)) and not Queue[1].Fading then
		Queue[1].Fading = true
		Fade:Play("In", true)
	  end
	  if Fade:IsFinished("In") and Queue[1].Fading then
		Queue[1].Faded = true
	  end
	  for p = 0, game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(p)
		if Queue[1].Skip and Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, player.ControllerIndex) then
		  endNightmare()
		  return
		end
	  end
	  if Queue[1].Faded then
		endNightmare()
		return
	  end
	  local CenterX, CenterY = GetScreenSize()
	  BackgroundSpr:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
	  BackgroundSpr:Update()
	  if Queue[1].Ready then
		NightmareSpr:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
		NightmareSpr:Update()
	  end
	  if Queue[1].Fading then
		Fade:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
		Fade:Update()
	  end
	end
  elseif (shaderName == 'ScreenAPIShader') and Queue[1] and Queue[1].Type == "Custom" then
	if not IsGamePaused() then
	  if (ModConfigMenu and ModConfigMenu.IsVisible) then
		ModConfigMenu.CloseConfigMenu()
	  end
	  if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then
		DeadSeaScrollsMenu:CloseMenu(true, true)
	  end
	  FreezeGame()
	  if not loaded then
		loaded = true
		CustomSpr:Load(Queue[1].Anm2, true)
	  end
	  if not OverrideControls then
		OverrideControls = true
		for p = 0, game:GetNumPlayers() - 1 do
		  local player = Isaac.GetPlayer(p)
		  local data = player:GetData()
		  if not data.GiantbookAPIControls then
			data.GiantbookAPIControls = player.Velocity
			player.ControlsEnabled = false
			player.Velocity = nullVector
		  end
		end
	  end
	  if not Queue[1].Appear then
		CustomSpr:Play(Queue[1].Anim, true)
		frame = game:GetFrameCount()
		Queue[1].Appear = true
	  end
	  if (not Queue[1].Duration and CustomSpr:IsFinished(Queue[1].Anim)) or (Queue[1].Duration and Queue[1].Duration + frame == game:GetFrameCount()) then
		table.remove(Queue, 1)
		loaded = false
		if (not Queue[1]) and OverrideControls then
		  OverrideControls = false
		  for p = 0, game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(p)
			local data = player:GetData()
			if data.GiantbookAPIControls then
			  player.ControlsEnabled = true
			  player.Velocity = data.GiantbookAPIControls
			  data.GiantbookAPIControls = nil
			end
		  end
		  FreezeGame(true)
		end
		return
	  end
	  local CenterX, CenterY = GetScreenSize()
	  CustomSpr:Render(Vector(CenterX / 2, CenterY / 2), nullVector, nullVector)
	  CustomSpr:Update()
	end
  elseif (shaderName == 'ScreenAPIShader') and Queue[1] and Queue[1].Type == "Cutscene" then
	if not IsGamePaused() or Queue[1].Started then
	  if (ModConfigMenu and ModConfigMenu.IsVisible) then
		ModConfigMenu.CloseConfigMenu()
	  end
	  if (DeadSeaScrollsMenu and DeadSeaScrollsMenu.OpenedMenu) then
		DeadSeaScrollsMenu:CloseMenu(true, true)
	  end
	  FreezeGame()
	  Queue[1].Started = true
	  music:Pause()
	  for i = 1, getMaxSoundID() do
		if i ~= Queue[1].Sound and sound:IsPlaying(i) then
		  sound:Stop(i)
		end
	  end
	  local function preEndGame()
		game:FinishChallenge()
		for i = 1, 10 do --Force 10 game updates to speed up the animation
		  game:Update()
		end
	  end
	  local function endGame()
		sound:Stop(Queue[1].Sound)
		Queue = {}
		loaded = false
		if (not Queue[1]) and OverrideControls then
		  OverrideControls = false
		  for p = 0, game:GetNumPlayers() - 1 do
			local player = Isaac.GetPlayer(p)
			local data = player:GetData()
			if data.GiantbookAPIControls then
			  player.ControlsEnabled = true
			  player.Velocity = data.GiantbookAPIControls
			  data.GiantbookAPIControls = nil
			end
		  end
		  FreezeGame(true)
		end
	  end
	  if not loaded then
		loaded = true
		CutsceneStr:Load(Queue[1].Anm2, true)
	  end
	  if not OverrideControls then
		OverrideControls = true
		for p = 0, game:GetNumPlayers() - 1 do
		  local player = Isaac.GetPlayer(p)
		  local data = player:GetData()
		  if not data.GiantbookAPIControls then
			data.GiantbookAPIControls = player.Velocity
			player.ControlsEnabled = false
			player.Velocity = nullVector
		  end
		end
	  end
	  if not Queue[1].Appear then
		CutsceneStr:Play(CutsceneStr:GetDefaultAnimation(), true)
		Queue[1].Appear = true
		sound:Play(Queue[1].Sound, 2)
	  end
	  local t = 29
	  for p = 0, game:GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(p)
		if Queue[1].Skip and Input.IsActionTriggered(ButtonAction.ACTION_MENUCONFIRM, player.ControllerIndex) then
		  Queue[1].EndTimer = t
		  preEndGame()
		end
	  end
	  if not Queue[1].EndTimer and Queue[1].Frame and CutsceneStr:GetFrame() + 30 >= Queue[1].Frame then
		Queue[1].EndTimer = t
		preEndGame()
	  end
	  if Queue[1].EndTimer and Queue[1].EndTimer >= 0 then
		Queue[1].EndTimer = Queue[1].EndTimer - 1
	  end
	  if Queue[1].EndTimer and Queue[1].EndTimer == 0 then
		endGame()
		return
	  end
	  local RenderX, RenderY = GetScreenSize()
	  if Queue[1].Shadow then
		CutsceneBack:SetFrame("Scene", 1)
	  else
		CutsceneBack:SetFrame("Scene", 2)
	  end
	  CutsceneBack:Render(Vector(RenderX / 2, RenderY / 2), nullVector, nullVector)
	  CutsceneStr:Render(Vector(RenderX / 2, RenderY / 2), nullVector, nullVector)
	  CutsceneStr:Update()
	end
  end
end)

--Custom Shader Fix by AgentCucco
ScreenAPI:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
  if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
	Isaac.ExecuteCommand("reloadshaders")
  end
end)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PistolConfig = require(ReplicatedStorage.Shared.PistolConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.ProgressionConfig)
local TalentConfig = require(ReplicatedStorage.Shared.TalentConfig)

local ProgressionService = {}
local states = {}
local started = false
local onChoicesChanged

local function requiredXP(level)
	if TalentConfig.DebugMode and TalentConfig.FastLeveling then
		return ProgressionConfig.ZombieKillXP
	end
	return ProgressionConfig.FirstLevelXP + (level - 1) * ProgressionConfig.XPIncreasePerLevel
end

local function syncProgress(player, state)
	player:SetAttribute("PlayerLevel", state.Level)
	player:SetAttribute("PlayerXP", state.XP)
	player:SetAttribute("PlayerRequiredXP", requiredXP(state.Level))
	player:SetAttribute("PendingTalentChoices", state.PendingTalentChoices)
end

local function applyHealth(player, state, previousBonus)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	if not state.BaseMaxHealth then state.BaseMaxHealth = humanoid.MaxHealth - previousBonus end
	local newMax = state.BaseMaxHealth + state.MaxHealthBonus
	local gained = state.MaxHealthBonus - previousBonus
	humanoid.MaxHealth = newMax
	humanoid.Health = math.clamp(humanoid.Health + math.max(0, gained), 0, newMax)
end

local function initializePlayer(player)
	if states[player] then return end
	local state = {
		Level = 1, XP = 0, PendingTalentChoices = 0,
		BaseDamageMultiplier = 1, HeadshotDamageMultiplier = 1,
		ReloadSpeedMultiplier = 1, MagazineBonus = 0, MaxHealthBonus = 0,
		PiercingCount = 0, DeadeyeStreak = 0,
		CombatReloadReady = false, CombatReloadMultiplier = 1,
		OwnedTalents = {}, VoltaBoonCount = 0, BaseMaxHealth = nil,
	}
	states[player] = state
	syncProgress(player, state)
	ProgressionService.refreshCombatAttributes(player)
	local function onCharacterAdded(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if player.Character ~= character or not humanoid then return end
		if not state.BaseMaxHealth then state.BaseMaxHealth = humanoid.MaxHealth end
		applyHealth(player, state, 0)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then task.spawn(onCharacterAdded, player.Character) end
end

function ProgressionService.start()
	if started then return end
	started = true
	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do initializePlayer(player) end
end

function ProgressionService.getState(player)
	return states[player]
end

function ProgressionService.setChoicesChangedCallback(callback)
	onChoicesChanged = callback
end

function ProgressionService.refreshCombatAttributes(player)
	local state = states[player]
	if not state then return end
	player:SetAttribute("PistolMaxMagazine", PistolConfig.MagazineSize + state.MagazineBonus)
	if player:GetAttribute("PistolReloading") ~= true then
		player:SetAttribute("PistolReloadDuration", math.max(
			ProgressionConfig.MinimumReloadDuration,
			PistolConfig.ReloadDuration * state.ReloadSpeedMultiplier
		))
	end
end

function ProgressionService.applyVitality(player, previousBonus)
	local state = states[player]
	if state then applyHealth(player, state, previousBonus) end
end

function ProgressionService.awardKillXP(player, zombie)
	local state = states[player]
	if not state or player.Parent ~= Players or not zombie or zombie:GetAttribute("IsZombie") ~= true
		or zombie:GetAttribute("XPAwarded") == true then
		return false
	end
	zombie:SetAttribute("XPAwarded", true)
	state.XP += ProgressionConfig.ZombieKillXP
	local gainedChoices = false
	while state.XP >= requiredXP(state.Level) do
		state.XP -= requiredXP(state.Level)
		state.Level += 1
		state.PendingTalentChoices += 1
		gainedChoices = true
	end
	syncProgress(player, state)
	if gainedChoices and onChoicesChanged then
		local success, failure = pcall(onChoicesChanged, player)
		if not success then warn("[ProgressionService] Could not refresh talent choices:", failure) end
	end
	return true
end

function ProgressionService.consumeChoice(player)
	local state = states[player]
	if not state or state.PendingTalentChoices <= 0 then return false end
	state.PendingTalentChoices -= 1
	syncProgress(player, state)
	return true
end

return ProgressionService

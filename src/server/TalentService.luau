local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Definitions = require(ReplicatedStorage.Shared.TalentDefinitions)
local TalentConfig = require(ReplicatedStorage.Shared.TalentConfig)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))

local TalentService = {}
local shocked = setmetatable({}, { __mode = "k" })

local function ownedTier(state, id)
	local owned = state and state.OwnedTalents[id]
	return owned and owned.Tier or nil
end

local function values(state, id)
	local definition = Definitions.ById[id]
	local tier = ownedTier(state, id)
	local data = tier and definition.Tiers[tier]
	return data and data.Values or nil
end

local function prerequisitesMet(state, definition)
	local prerequisite = definition.Prerequisites
	if not prerequisite then return true end
	for _, id in prerequisite.RequiredTalents or {} do
		if not ownedTier(state, id) then return false end
	end
	if prerequisite.AdditionalVoltaBoon then
		if not ownedTier(state, "StaticShock") and not ownedTier(state, "ConductiveTarget") then
			return false
		end
	end
	return true
end

function TalentService.canGrant(player, id, tier)
	local state = ProgressionService.getState(player)
	local definition = Definitions.ById[id]
	if not state or not definition or not definition.Tiers[tier] or tier == "Gold" then return false end
	local current = ownedTier(state, id)
	if current then
		if not definition.Upgradeable or current ~= "Blue" or tier ~= "Purple" then return false end
	end
	if not prerequisitesMet(state, definition) then return false end
	return true
end

local function recalculate(player, state, previousHealthBonus)
	local sharpshooter = values(state, "Sharpshooter")
	local quickHands = values(state, "QuickHands")
	local magazine = values(state, "ExtendedMagazine")
	local vitality = values(state, "Vitality")
	local caliber = values(state, "LargeCaliber")
	local piercing = values(state, "APCore")
	local combatReload = values(state, "CombatReload")
	state.HeadshotDamageMultiplier = 1 + (sharpshooter and sharpshooter.HeadshotBonus or 0)
	state.ReloadSpeedMultiplier = 1 - (quickHands and quickHands.ReloadReduction or 0)
	state.MagazineBonus = magazine and magazine.MagazineBonus or 0
	state.MaxHealthBonus = vitality and vitality.MaxHealthBonus or 0
	state.BaseDamageMultiplier = 1 + (caliber and caliber.BaseDamageBonus or 0)
	state.PiercingCount = piercing and piercing.PiercingCount or 0
	state.CombatReloadMultiplier = 1 - (combatReload and combatReload.NextReloadReduction or 0)
	local voltaCount = 0
	for id in state.OwnedTalents do
		if Definitions.ById[id].Patron == "Professor Volta" then voltaCount += 1 end
	end
	state.VoltaBoonCount = voltaCount
	ProgressionService.refreshCombatAttributes(player)
	if state.MaxHealthBonus ~= previousHealthBonus then
		ProgressionService.applyVitality(player, previousHealthBonus)
	end
end

function TalentService.grant(player, id, tier)
	if not TalentService.canGrant(player, id, tier) then return false end
	local state = ProgressionService.getState(player)
	if state.PendingTalentChoices <= 0 then return false end
	local previousHealthBonus = state.MaxHealthBonus
	state.OwnedTalents[id] = { Tier = tier, Count = 1 }
	recalculate(player, state, previousHealthBonus)
	return true
end

function TalentService.getTier(player, id)
	return ownedTier(ProgressionService.getState(player), id)
end

local function eligible(player, tier, used)
	local pool = {}
	for _, id in Definitions.Order do
		if not used[id] and TalentService.canGrant(player, id, tier) then
			table.insert(pool, { Id = id, Tier = tier })
		end
	end
	return pool
end

local function choose(pool, deterministic)
	if #pool == 0 then return nil end
	return pool[if deterministic then 1 else math.random(1, #pool)]
end

function TalentService.rollChoices(player)
	local used = {}
	local choices = {}
	for slot = 1, 3 do
		local choice
		if TalentConfig.DebugMode then
			local tier = TalentConfig.DebugRollSlots[slot]
			choice = choose(eligible(player, tier, used), true)
		else
			local red = eligible(player, "Red", used)
			if #red > 0 and math.random() < TalentConfig.MythicReplacementChance then
				choice = choose(red, false)
			end
		end
		if not choice then
			local preferred = if math.random(1, TalentConfig.BlueWeight + TalentConfig.PurpleWeight)
				<= TalentConfig.BlueWeight then "Blue" else "Purple"
			choice = choose(eligible(player, preferred, used), TalentConfig.DebugMode)
				or choose(eligible(player, if preferred == "Blue" then "Purple" else "Blue", used), TalentConfig.DebugMode)
		end
		if not choice then
			choice = choose(eligible(player, "Red", used), TalentConfig.DebugMode)
		end
		if not choice then return nil end
		used[choice.Id] = true
		table.insert(choices, choice)
	end
	return choices
end

function TalentService.onHit(context)
	if not context.AffectsStreak then return end
	local state = ProgressionService.getState(context.Player)
	if not state then return end
	if context.IsHeadshot then
		if ownedTier(state, "Deadeye") then
			state.DeadeyeStreak = math.min(5, state.DeadeyeStreak + 1)
		end
	else
		state.DeadeyeStreak = 0
	end
end

function TalentService.onMiss(player)
	local state = ProgressionService.getState(player)
	if state then state.DeadeyeStreak = 0 end
end

function TalentService.isShocked(model)
	return (model:GetAttribute("ShockedUntil") or 0) > os.clock()
end

function TalentService.clearShock(model)
	shocked[model] = nil
	model:SetAttribute("ShockedUntil", 0)
end

local function applyShock(model, duration)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local old = shocked[model]
	local baseSpeed = if old then old.BaseSpeed else humanoid.WalkSpeed
	local expires = math.max(if old then old.Expires else 0, os.clock() + duration)
	local state = { BaseSpeed = baseSpeed, Expires = expires }
	shocked[model] = state
	model:SetAttribute("ShockedUntil", expires)
	humanoid.WalkSpeed = 0
	task.delay(math.max(0, expires - os.clock()), function()
		if shocked[model] ~= state then return end
		shocked[model] = nil
		if model.Parent and humanoid.Health > 0 then
			model:SetAttribute("ShockedUntil", 0)
			humanoid.WalkSpeed = baseSpeed
		end
	end)
end

local function nearestChainTarget(origin, visited)
	local best, bestDistance = nil, TalentConfig.ArcRadius
	for _, model in CollectionService:GetTagged("Zombie") do
		if model:IsA("Model") and model:IsDescendantOf(workspace) and not visited[model]
			and model:GetAttribute("IsDead") ~= true then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				local distance = (root.Position - origin).Magnitude
				if distance <= bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

function TalentService.onHeadshot(context, applyLightningDamage)
	if not context.CanTriggerOnHitTalents then return end
	local state = ProgressionService.getState(context.Player)
	if not state then return end
	local shock = values(state, "StaticShock")
	if shock and math.random() < shock.ShockChance then
		applyShock(context.Target, shock.ShockDuration)
	end
	local arc = values(state, "ArcDischarge")
	if not arc then return end
	local cascade = values(state, "TeslaCascade")
	local count = math.min(5, arc.ChainCount + (cascade and cascade.AdditionalChains or 0))
	local visited = { [context.Target] = true }
	local root = context.Target:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else context.HitPosition
	for _ = 1, count do
		local target = nearestChainTarget(origin, visited)
		if not target then break end
		visited[target] = true
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then origin = targetRoot.Position end
		applyLightningDamage(target, arc.ChainDamage)
	end
end

function TalentService.onKill(_context)
	-- Kill XP is centralized in ProgressionService; this hook is for later boons.
end

function TalentService.onHeadshotKill(context)
	if context.DamageSource ~= "Bullet" then return end
	local state = ProgressionService.getState(context.Player)
	if state and ownedTier(state, "CombatReload") then
		state.CombatReloadReady = true
	end
end

function TalentService.onReload(_player, _duration)
	-- Called only for an accepted server reload; transient bonuses are consumed there.
end

function TalentService.onDamageTaken(_player, _damage, _source)
	-- No Phase B talent reacts to player damage, but the server hook is ready.
end

return TalentService

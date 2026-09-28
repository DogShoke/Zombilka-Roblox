local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PistolConfig = require(ReplicatedStorage.Shared.PistolConfig)
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local TalentService = require(script.Parent:WaitForChild("TalentService"))

local CombatService = {}
local feedbackRemote

local function livingZombie(model)
	if not model or not model:IsA("Model") or not model:IsDescendantOf(workspace)
		or model:GetAttribute("IsZombie") ~= true or model:GetAttribute("IsDead") == true then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return humanoid
end

local function applyDamage(context)
	local humanoid = livingZombie(context.Target)
	local state = ProgressionService.getState(context.Player)
	if not humanoid or not state then return nil end
	if context.HitPart and not context.HitPart:IsDescendantOf(context.Target) then return nil end
	if context.DamageSource == "Bullet" then
		TalentService.onHit(context)
	end
	local damage = context.BaseDamage
	if context.DamageSource == "Bullet" then
		damage *= state.BaseDamageMultiplier
		if context.IsHeadshot then
			damage *= PistolConfig.HeadshotMultiplier
			damage *= state.HeadshotDamageMultiplier
			if TalentService.getTier(context.Player, "Deadeye") then
				damage *= 1 + math.min(5, state.DeadeyeStreak) * 0.10
			end
		end
	end
	if TalentService.getTier(context.Player, "ConductiveTarget") and TalentService.isShocked(context.Target) then
		damage *= 1.25
	end
	context.FinalDamage = damage
	humanoid:TakeDamage(damage)
	context.Killed = humanoid.Health <= 0
	if context.Killed then
		ProgressionService.awardKillXP(context.Player, context.Target)
		TalentService.onKill(context)
		if context.IsHeadshot then TalentService.onHeadshotKill(context) end
	end
	if context.IsHeadshot and context.DamageSource == "Bullet" then
		TalentService.onHeadshot(context, function(target, lightningDamage)
			CombatService.applyTalentDamage(context.Player, target, lightningDamage)
		end)
	end
	return context
end

function CombatService.start(remote)
	feedbackRemote = remote
end

function CombatService.processHit(player, model, hitPart, hitPosition, weaponId, baseDamage, isPrimary)
	local context = {
		Player = player,
		WeaponId = weaponId,
		Target = model,
		HitPart = hitPart,
		IsHeadshot = hitPart.Name == "Head",
		BaseDamage = baseDamage,
		FinalDamage = 0,
		Killed = false,
		HitPosition = hitPosition,
		DamageSource = "Bullet",
		AffectsStreak = isPrimary,
		CanTriggerOnHitTalents = true,
	}
	local result = applyDamage(context)
	if result and isPrimary and feedbackRemote then
		feedbackRemote:FireClient(player, if result.IsHeadshot then "Headshot" else "Hit")
	end
	return result
end

function CombatService.applyTalentDamage(player, model, damage)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return applyDamage({
		Player = player,
		WeaponId = "ArcDischarge",
		Target = model,
		HitPart = nil,
		IsHeadshot = false,
		BaseDamage = damage,
		FinalDamage = 0,
		Killed = false,
		HitPosition = if root and root:IsA("BasePart") then root.Position else Vector3.zero,
		DamageSource = "Lightning",
		AffectsStreak = false,
		CanTriggerOnHitTalents = false,
	})
end

function CombatService.onMiss(player)
	TalentService.onMiss(player)
end

function CombatService.onDamageTaken(player, damage, source)
	TalentService.onDamageTaken(player, damage, source)
end

return CombatService

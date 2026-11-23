local AttackTypes = {}

local TypesConfig = {
	Normal = {
		DamageType = "Normal",
		Cost = 0,
		ParryCooldwon = 3,
		ComboResetTime = 1,

		Projectile = {
			Cooldown = 0.5,
			Speed = 50,
			LifeTime = 4,
			Damage = 5,
			StunTime = 0,
			MaxQueued = 5,
		},

		Abilities = {
			Burst = {
				Cooldown = 4,
				Bullets = 8,
				SpawnRadius = 1.5,
				Speed = 35,
				LifeTime = 2,
				Damage = 3,
				StunTime = 0,
				Scale = 0.5,
			},
			Enlarge = {
				Cooldown = 4,
				Scale = 2.8,
				Speed = 50,
				Damage = 15,
				StunTime = 1,
			},
			HomingProjectile = {
				Cooldown = 4,
				Speed = 50,
				LifeTime = 4,
				Damage = 10,
				StunTime = 0,
				MaxQueued = 5,
			},
		},

		Dashes = {
			Front = {
				Speed = 100,
				Time = 0.3,
				Cooldown = 2,
				Hits = true,
				HitBox = {5, 5, 5},
				Damage = 10,
				StunTime = 0.5,
				EvadeTime = 0,
				KeepFacing = false,
				AttackWindow = 0.5,
				AnimationId = "",
			},
			Back = {
				Speed = 80,
				Time = 0.25,
				Cooldown = 1.5,
				Hits = false,
				EvadeTime = 0.2,
				KeepFacing = true,
				AttackWindow = 0.8,
				AnimationId = "rbxassetid://122645740187928",
			},
			Left = {
				Speed = 80,
				Time = 0.25,
				Cooldown = 1.5,
				Hits = false,
				EvadeTime = 0.5,
				KeepFacing = true,
				AttackWindow = 0.15,
				AnimationId = "",
			},
			Right = {
				Speed = 80,
				Time = 0.25,
				Cooldown = 1.5,
				Hits = false,
				EvadeTime = 0.5,
				KeepFacing = true,
				AttackWindow = 0.15,
				AnimationId = "rbxassetid://96788914394788",
			},
		},

		Hits = {
			{
				Damage = 5,
				Cooldown = 0.4,
				HitDelay = 0.2, 
				HitBox = {5, 5, 5},
				AnimationId = "rbxassetid://92777911929022",
				StunTime = 0.5,
			},
			{
				Damage = 5,
				Cooldown = 0.4,
				HitDelay = 0.2,
				HitBox = {5, 5, 5},
				AnimationId = "rbxassetid://106898930533979",
				StunTime = 0.5,
			},
			{
				Damage = 5,
				Cooldown = 0.4,
				HitDelay = 0.2,
				HitBox = {5, 5, 5},
				AnimationId = "rbxassetid://112698709430465",
				StunTime = 0.5,
			},
			{
				Damage = 10,
				Cooldown = 1,
				HitDelay = 0.3,
				HitBox = {6, 6, 6},
				AnimationId = "rbxassetid://83220119473552",
				StunTime = 0.5,
			},
		},
	},
}


function AttackTypes.GetConfig(Type)
	return TypesConfig[Type]
end

function AttackTypes.GetHit(Type, Index)
	local Config = TypesConfig[Type]
	if not Config or type(Index) ~= "number" then return nil end
	return Config.Hits[Index]
end

function AttackTypes.GetDash(Type, Direction)
	local Config = TypesConfig[Type]
	if not Config or not Config.Dashes or type(Direction) ~= "string" then return nil end
	return Config.Dashes[Direction]
end

function AttackTypes.GetProjectile(Type)
	local Config = TypesConfig[Type]
	return Config and Config.Projectile
end

function AttackTypes.GetAbility(Type, AbilityName)
	local Config = TypesConfig[Type]
	if not Config or not Config.Abilities or type(AbilityName) ~= "string" then return nil end
	return Config.Abilities[AbilityName]
end

return AttackTypes
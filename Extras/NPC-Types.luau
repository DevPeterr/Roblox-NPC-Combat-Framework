local npcData = {}

local NPCs = {
	["Merchants"] = {
		["John"] = {
			["Name"] = "John",
			["Health"] = nil,
		}
	},
	["Warriors"] = {
		["Arthur"] = {
			["Name"] = "Arthur",
			["Health"] = 100,
			["Damage"] = 10,
			["WalkRadius"] = 15,
			["AttackDistance"] = 5,
			["AttackCooldown"] = 2,
			["AttackAnimationID"] ="rbxassetid://92777911929022" 
		},
		["Karl"] = {
			["Name"] = "Karl",
			["Health"] = 100,
			["Damage"] = 10,
			["WalkRadius"] = 15,
			["AttackDistance"] = 5,
			["AttackCooldown"] = 2,
			["AttackAnimationID"] = "rbxassetid://92777911929022"
		},
	},
	["Guardians"] = {
		["Aegis"] = {
			["Name"] = "Aegis",
			["Health"] = 500,
			["Damage"] = 20
		},
		["Brutus"] = {
			["Name"] = "Brutus",
			["Health"] = 600,
			["Damage"] = 10,
			["Radius"] = 30,
			["AttackDistance"] = 5,
			["AttackCooldown"] = 2,
			["HealAmount"] = 5,
			["HealCooldown"] = 1,
		}
	},
	
}

function npcData.GetAllNPCs()
	return NPCs
end

function npcData.GetMerchantData(Name)
	return NPCs.Merchants[Name]
end

function npcData.GetWarriorData(Name)
	return NPCs.Warriors[Name]
end

function npcData.GetGuardianData(Name)
	return NPCs.Guardians[Name]
end

return npcData
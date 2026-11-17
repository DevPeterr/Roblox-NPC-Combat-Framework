local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")


local NPC = require(script.Parent)
local npcData = require(ReplicatedStorage.Data.Types)

local WAIT = 4

local Warrior = {}
Warrior.__index = Warrior
setmetatable(Warrior, NPC)

function Warrior.new(name)
	local self = NPC.new("Warrior", name)
	setmetatable(self, Warrior)
	self.Data = npcData.GetWarriorData(name)
	
	return self
end

function Warrior:StartChasing()
	local WalkRadius = self.Data.WalkRadius
	local RandomPoint = Vector3.new(math.random(-WalkRadius, WalkRadius), 0, math.random(-WalkRadius, WalkRadius))
	print(RandomPoint)
	NPC.StartChasing(self, 50)
	task.spawn(function()
		while self.Target == nil do
			task.wait(WAIT)
			NPC.MoveTo(self, RandomPoint)
			WAIT = math.random(2, 4)
			RandomPoint = Vector3.new(math.random(-WalkRadius, WalkRadius), 0, math.random(-WalkRadius, WalkRadius))
			task.wait(WAIT)
		end
	end)
end

function Warrior:CanDetectPlayer(Player: Player, Distance: number)
	return NPC.CanDetectPlayer(self, Player, Distance, 0)
end

function Warrior:SetAttackCooldown()
	NPC.SetAttackCooldown(self, self.Data.AttackCooldown)
end


return Warrior

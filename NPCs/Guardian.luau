local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")


local NPC = require(script.Parent)
local npcData = require(ReplicatedStorage.Data.Types)


local Guardian = {}
Guardian.__index = Guardian
setmetatable(Guardian, NPC)

function Guardian.new(name)
	local self = NPC.new("Guardian", name)
	setmetatable(self, Guardian)
	self.Data = npcData.GetGuardianData(name)
	
	
	
	return self
	
end

function Guardian:CreateAndSpawn()
	NPC.CreateAndSpawn(self)
	self.Model.Humanoid.Health = self.Data.Health
end

function Guardian:StartChasing()
	local CentrePoint = Vector3.new(5, 0, 5)

	NPC.StartChasing(self, 50)

	task.spawn(function()
		while self.Model and self.Model.Parent do
			local Root = self.Model.HumanoidRootPart

			local DistanceFromCentre = (Root.Position - CentrePoint).Magnitude
			self.Returning = false

			if DistanceFromCentre > self.Data.Radius then
				self.Returning = true
				self.Target = nil
				self.TargetVersion += 1

				NPC.MoveTo(self, CentrePoint)
				self.Model.Humanoid.MoveToFinished:Wait()

				self.Returning = false
			end
			task.wait(0.2)
		end
	end)
end

function Guardian:Heal()
	task.spawn(function()
		while self.Model and self.Model.Parent do
			self.Model.Humanoid.Health += self.Data.HealAmount
			task.wait(self.Data.HealCooldown)
		end
	end)
end

function Guardian:CanDetectPlayer(Player: Player, Distance: number)
	return NPC.CanDetectPlayer(self, Player, Distance, -1)
end

function Guardian:SetAttackCooldown()
	NPC.SetAttackCooldown(self, self.Data.AttackCooldown)
end

return Guardian

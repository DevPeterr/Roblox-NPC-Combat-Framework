local NPC = require(script.Parent)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local npcData = require(ReplicatedStorage.Data.Types)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MerchantPurchase = ReplicatedStorage.FunctionsAndEvents:WaitForChild("MerchantPurchase")
local PendingPurchases = {}

MerchantPurchase.OnServerEvent:Connect(function(player, Action)
	if Action == "Cancel" then
		PendingPurchases[player] = nil
		return
	end

	if Action ~= "Confirm" then return end

	local Expiry = PendingPurchases[player]
	if not Expiry or os.clock() > Expiry then return end

	PendingPurchases[player] = nil

	local Leaderstats = player:FindFirstChild("leaderstats")
	local Coins = Leaderstats and Leaderstats:FindFirstChild("Coins")

	if not Coins then return end

	if Coins.Value < 10 then
		MerchantPurchase:FireClient(player, "Message", "You don't have enough coins!")
		return
	end

	if player:GetAttribute("DamageUpgradePurchased") then
		MerchantPurchase:FireClient(player, "Message", "You already own this upgrade!")
		return
	end

	Coins.Value -= 10

	player:SetAttribute("DamageBonus", 15)
	player:SetAttribute("DamageUpgradePurchased", true)

	MerchantPurchase:FireClient(player, "Message", "Damage upgraded by 15!")
end)

Players.PlayerRemoving:Connect(function(player)
	PendingPurchases[player] = nil
end)


local Merchant = {}
Merchant.__index = Merchant
setmetatable(Merchant, NPC)

function Merchant.new(name)
	local self = NPC.new("Merchant", name)
	setmetatable(self, Merchant)
	self.Data = npcData.GetMerchantData(name)
	

	return self
end


function Merchant:CreateAndSpawn()
	NPC.CreateAndSpawn(self)
	local humanoid = self.Model:WaitForChild("Humanoid")
	humanoid.Health = humanoid.MaxHealth
	humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
	local Root = self.Model:WaitForChild("HumanoidRootPart")
	local ProximityPrompt = Instance.new("ProximityPrompt")
	ProximityPrompt.ActionText = "Talk"
	ProximityPrompt.ObjectText = "Merchant"
	ProximityPrompt.MaxActivationDistance = 12
	ProximityPrompt.RequiresLineOfSight = false
	ProximityPrompt.HoldDuration = 0
	ProximityPrompt.Enabled = true
	ProximityPrompt.Parent = Root

	ProximityPrompt.Triggered:Connect(function(player)
		PendingPurchases[player] = os.clock() + 30
		MerchantPurchase:FireClient(player, "Ask")
	end)
	
	self.NearbyPlayers = {}

	local CheckInterval = 0.2
	local Elapsed = 0

	self.ProximityConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		if not self.Model or not self.Model.Parent then
			self.ProximityConnection:Disconnect()
			self.ProximityConnection = nil
			return
		end
		Elapsed += DeltaTime
		if Elapsed < CheckInterval then return end
		Elapsed = 0
		local MerchantRoot = self.Model:FindFirstChild("HumanoidRootPart")
		if not MerchantRoot then return end

		for _, Player in Players:GetPlayers() do
			local Character = Player.Character
			local PlayerRoot = Character and Character:FindFirstChild("HumanoidRootPart")

			local IsNearby = PlayerRoot
				and (PlayerRoot.Position - MerchantRoot.Position).Magnitude <= 15

			if IsNearby and not self.NearbyPlayers[Player] then
				self.NearbyPlayers[Player] = true

				

			elseif not IsNearby then
				self.NearbyPlayers[Player] = nil
			end
		end
	end)
end

function Merchant:Destroy()
	if self.ProximityConnection then
		self.ProximityConnection:Disconnect()
		self.ProximityConnection = nil
	end

	NPC.Destroy(self)
end


return Merchant

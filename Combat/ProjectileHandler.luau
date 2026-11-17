
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local AttackTypes = require(ReplicatedStorage.Data.AttackTypes)
local AttackHandeler = require(script.Parent)
local ProjectileQueue = require(script.ProjectileQueue)

local Template = ServerStorage:WaitForChild("Projectile")
assert(
	Template:IsA("BasePart") or Template:IsA("Model"),
	"ServerStorage.Projectile must be a Part, MeshPart or Model"
)

local SPAWN_DISTANCE = 3 
local SPAWN_HEIGHT = 2 
local COOLDOWN_KEY = "Projectile"

local Queues = {} 


local function GetProjectileFolder()
	local Folder = workspace:FindFirstChild("Projectiles")
	if not Folder then
		Folder = Instance.new("Folder")
		Folder.Name = "Projectiles"
		Folder.Parent = workspace
	end
	return Folder
end


local function IsAlive(Projectile: Instance): boolean
	return Projectile.Parent ~= nil
end

local function GetQueue(Owner: Player)
	local Queue = Queues[Owner]
	if not Queue then
		Queue = ProjectileQueue.new(IsAlive)
		Queues[Owner] = Queue
	end
	return Queue
end

Players.PlayerRemoving:Connect(function(Owner)
	local Queue = Queues[Owner]
	if not Queue then return end

	for _, Projectile in Queue:Clear() do
		Projectile:Destroy()
	end
	Queues[Owner] = nil
end)


local function Prepare(Projectile: Instance): (BasePart, {BasePart})
	local Parts = {}

	if Projectile:IsA("BasePart") then
		table.insert(Parts, Projectile)
	else
		for _, Descendant in Projectile:GetDescendants() do
			if Descendant:IsA("BasePart") then
				table.insert(Parts, Descendant)
			end
		end
	end
	assert(#Parts > 0, "ServerStorage.Projectile has no parts inside it")

	local Primary = Parts[1]
	if Projectile:IsA("Model") then
		Primary = Projectile.PrimaryPart or Parts[1]
		Projectile.PrimaryPart = Primary
	end

	for _, Part in Parts do
		Part.Anchored = false
		Part.CanCollide = false
		Part.CanTouch = false

		if Part ~= Primary then
			Part.Massless = true

			local Weld = Instance.new("WeldConstraint")
			Weld.Part0 = Primary
			Weld.Part1 = Part
			Weld.Parent = Primary
		end
	end

	return Primary, Parts
end


local function WatchForHits(Projectile: Instance, Primary: BasePart, Parts: {BasePart}, Owner: Player, Config)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Owner.Character, GetProjectileFolder()}

	local Connection
	Connection = RunService.Heartbeat:Connect(function()
		if not Projectile.Parent then 
			Connection:Disconnect()
			return
		end

		for _, Detector in Parts do
			for _, Part in workspace:GetPartsInPart(Detector, Params) do
				local Model = Part:FindFirstAncestorWhichIsA("Model")
				local Target = Model and Model:FindFirstChildOfClass("Humanoid")

				if Target and Target.Health > 0 then
					
					AttackHandeler.DealDamage(
						Primary,
						Target,
						Projectile:GetAttribute("Damage"),
						Projectile:GetAttribute("StunTime")
					)
					Projectile:Destroy()
					Connection:Disconnect()
					return
					
				elseif Part.CanCollide then
					Projectile:Destroy()
					Connection:Disconnect()
					return
				end
			end
		end
	end)
end


local ProjectileHandler = {}
ProjectileHandler.__index = ProjectileHandler


ProjectileHandler.Abilities = {}


function ProjectileHandler.Launch(Owner: Player, Origin: Vector3, Direction: Vector3, Config, Queue): Instance
	local Projectile = Template:Clone()
	Projectile.Parent = GetProjectileFolder()

	if Config.Scale then
		if Projectile:IsA("Model") then
			Projectile:ScaleTo(Config.Scale)
		else
			Projectile.Size *= Config.Scale
		end
	end

	local Primary, Parts = Prepare(Projectile)

	Projectile:PivotTo(CFrame.lookAt(Origin, Origin + Direction)) 
	Projectile:SetAttribute("OwnerUserId", Owner.UserId)
	Projectile:SetAttribute("Damage", Config.Damage)
	Projectile:SetAttribute("StunTime", Config.StunTime)

	Primary:SetNetworkOwner(nil)

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Primary

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.MaxForce = math.huge
	LinearVelocity.VectorVelocity = Direction * Config.Speed
	LinearVelocity.Parent = Primary

	Debris:AddItem(Projectile, Config.LifeTime)
	if Queue then
		Queue:Enqueue(Projectile)
	end
	WatchForHits(Projectile, Primary, Parts, Owner, Config)

	return Projectile
end


function ProjectileHandler.new(Owner: Player, AttackConfig)
	local self = setmetatable({}, ProjectileHandler)

	self.AttackConfig = AttackConfig
	self.Config = AttackConfig.Projectile 
	self.Owner = Owner
	self.Projectile = nil

	return self
end


function ProjectileHandler:FireProjectile(): Instance?
	local Owner = self.Owner
	local Config = self.Config
	if not Owner or not Config then return nil end

	local Character = Owner.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid or Humanoid.Health <= 0 then return nil end

	if AttackHandeler.HasAnyState(Owner, "Stunned", "Blocking", "Attacking", "Parrying", "DashLocked") then
		return nil
	end

	local Queue = GetQueue(Owner)
	if Queue:Size() >= Config.MaxQueued then return nil end
	if AttackHandeler.IsOnCooldown(Owner, COOLDOWN_KEY, Config.Cooldown) then return nil end

	local Direction = Root.CFrame.LookVector
	local Origin = Root.Position + Direction * SPAWN_DISTANCE + Vector3.new(0, SPAWN_HEIGHT, 0)

	self.Projectile = ProjectileHandler.Launch(Owner, Origin, Direction, Config, Queue)
	return self.Projectile
end


function ProjectileHandler.ActivateNext(Owner: Player, AttackType: string, AbilityName: string): Instance?
	local Ability = ProjectileHandler.Abilities[AbilityName]
	local Config = AttackTypes.GetAbility(AttackType, AbilityName)
	if not Ability or not Config then return nil end

	local Character = Owner.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return nil end
	if AttackHandeler.HasAnyState(Owner, "Stunned") then return nil end

	local Queue = Queues[Owner]
	if not Queue or not Queue:Peek() then return nil end


	if AttackHandeler.IsOnCooldown(Owner, "Ability_" .. AbilityName, Config.Cooldown) then return nil end

	local Projectile = Queue:Dequeue()
	if not Projectile then return nil end

	Ability(Projectile, Owner, Config)
	return Projectile
end

return ProjectileHandler
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathFindingServise = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local npcData = require(ReplicatedStorage.Data.Types)
local Types = require(ReplicatedStorage.Data.Types)

local RepathInterval = 1.5
local DetectionInterval = 0.2
local ChangeTargetToNil = 3
local Hitbox = ServerStorage.Hitbox
local HIT_WINDOW = 0.28           
local HITBOX_LINGER = 0.2         
local TOLERANCE = 0.15            
local MAX_PING_COMPENSATION = 0.3
local DefaultHitboxSize = Vector3.new(8.829, 5.927, 7.59)
local Coin = ReplicatedStorage.Coin
local CoinSpawnRadius = 10

local ActiveNPCs = {}

local function GetRoot(Attacker: Player | Model): BasePart?
	local Character: Model?

	if Attacker:IsA("Player") then
		Character = Attacker.Character
	else
		Character = Attacker
	end
	return Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function DetectHit(Attacker: Player | Model, HitBoxSize: Vector3): Humanoid?
	local Character: Model?
	local Root: BasePart?
	local Ping = 0

	if Attacker:IsA("Player") then
		Character = Attacker.Character
		Root = GetRoot(Attacker)
		Ping = math.min(Attacker:GetNetworkPing(), MAX_PING_COMPENSATION)
	else
		Character = Attacker
		Root = Attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	if not Character or not Root then 
		warn("Character or Root not found for attacker:", Attacker)
		return nil
	end

	local HitBoxClone = Hitbox:Clone()
	HitBoxClone.Size = HitBoxSize
	HitBoxClone.Anchored = true
	HitBoxClone.CanCollide = false
	HitBoxClone.CanTouch = false
	HitBoxClone.Parent = workspace
	print("Hitbox spawned:", HitBoxClone:GetFullName())
	Debris:AddItem(HitBoxClone, HIT_WINDOW + HITBOX_LINGER)

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, HitBoxClone}

	local Checked = {}
	local EndTime = os.clock() + HIT_WINDOW

	while os.clock() < EndTime and Root.Parent do
		local Predicted = Root.CFrame + Root.AssemblyLinearVelocity * Ping
		HitBoxClone.CFrame = Predicted * CFrame.new(0, 0, -HitBoxSize.Z / 2)

		for _, Part in workspace:GetPartsInPart(HitBoxClone, Params) do
			local Model = Part:FindFirstAncestorWhichIsA("Model")

			if Model and not Checked[Model] then
				Checked[Model] = true

				local Humanoid = Model:FindFirstChildOfClass("Humanoid")

				if Humanoid and Humanoid.Health > 0 then
					return Humanoid
				end
			end
		end

		task.wait()
	end

	return nil
end

local NPC = {}
NPC.__index = NPC


function NPC.new(Type: string, Name: string)
	local self = setmetatable({}, NPC)
	self.Type = Type
	self.Name = Name
	self.Model = nil
	self.Spawned = false
	self.Target = nil
	self.TargetVersion = 0
	self.IsChasing = false
	self.Stunned = false
	return self
end

function NPC:CreateAndSpawn()
	if self.Spawned then return end
	self.Model = ServerStorage.NPC[self.Type]:Clone()
	self.Model.Name = self.Name
	self.Model.Parent = workspace
	self.Model.HumanoidRootPart:SetNetworkOwner(nil)
	self.Spawned = true
	ActiveNPCs[self.Model] = self
	for _, Part in self.Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.CanQuery = true
		end
	end
end

function NPC:SetUp()
	NPC:CreateAndSpawn()
	NPC:StartChasing(50)
	NPC:SetAttackCooldown()
	NPC:StartAttackSequence()
end

function NPC.GetFromModel(Model: Model)
	return ActiveNPCs[Model]
end

function NPC:GetHumanoid()
	return self.Model:FindFirstChildOfClass("Humanoid")
end

function NPC:SetAttackCooldown(AttackCooldown)
	self.AttackCooldown = AttackCooldown
end

function NPC:PivotTo(Position: Vector3)
	self.Model:PivotTo(CFrame.new(Position))
end

function NPC:MoveTo(Position: Vector3)
	self.Model.Humanoid:MoveTo(Position)
end

function NPC:GetNearestPlayer(Distance: number)
	local NPCroot = self.Model.HumanoidRootPart

	local NearestPlayer = nil
	local ShortestDistance = Distance

	for _, Player in Players:GetPlayers() do
		local Character = Player.Character
		local PlayerRoot = Character and Character:FindFirstChild("HumanoidRootPart")

		if not PlayerRoot then continue end

		local CurrentDistance = (PlayerRoot.Position - NPCroot.Position).Magnitude

		if CurrentDistance < ShortestDistance
			and self:CanDetectPlayer(Player, Distance) then

			ShortestDistance = CurrentDistance
			NearestPlayer = Player
		end
	end

	return NearestPlayer
end

function NPC:CanDetectPlayer(Player: Player, Distance: number, Angle: number): boolean
	local NPCroot = GetRoot(self.Model)
	local Character = Player.Character
	local PlayerRoot = Character and Character:FindFirstChild("HumanoidRootPart")

	if not PlayerRoot then return false end

	local Direction = PlayerRoot.Position - NPCroot.Position
	local DistanceToPlayer = Direction.Magnitude

	if DistanceToPlayer == 0 or DistanceToPlayer > Distance then
		return false
	end

	local DotProduct = NPCroot.CFrame.LookVector:Dot(Direction.Unit)

	return DotProduct >= Angle
end


function NPC:PathFindToPlayer(Player: Player, TargetVersion: number)

	local Path = PathFindingServise:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 2,
		Costs = {
			["Water"] = math.huge,
		}
	})

	local NPCroot = self.Model.HumanoidRootPart
	local Humanoid = self.Model.Humanoid

	Humanoid.WalkSpeed = 24

	local Character = Player.Character
	local PlayerRoot = Character and Character:FindFirstChild("HumanoidRootPart")

	if not PlayerRoot then return end

	local Success, ErrorMessage = pcall(function()
		local StopDistance = 5
		local Offset = NPCroot.Position - PlayerRoot.Position
		local FlatOffset = Vector3.new(Offset.X, 0, Offset.Z)
		if FlatOffset.Magnitude < 0.001 then
			FlatOffset = -NPCroot.CFrame.LookVector
			FlatOffset = Vector3.new(FlatOffset.X, 0, FlatOffset.Z)
		end

		local ApproachPosition = PlayerRoot.Position + FlatOffset.Unit * StopDistance

		Path:ComputeAsync(NPCroot.Position, ApproachPosition)
	end)

	if not Success then
		warn("Path computation failed:", ErrorMessage)
		return
	end

	if TargetVersion ~= self.TargetVersion or Player.Character ~= Character then
		return
	end

	if Path.Status ~= Enum.PathStatus.Success then return end
	local CurrentWaypointIndex = 1
	local PathBlocked = false
	local RepathRequested = false
	local BlockedConnection = Path.Blocked:Connect(function(BlockedWaypointIndex)
		if BlockedWaypointIndex >= CurrentWaypointIndex then
			PathBlocked = true
		end

	end)

	local StartTime = os.clock()

	for Index, Waypoint in ipairs(Path:GetWaypoints()) do
		if self.Stunned or TargetVersion ~= self.TargetVersion or PathBlocked then
			break
		end
		if os.clock() - StartTime >= RepathInterval then
			RepathRequested = true
			break
		end

		CurrentWaypointIndex = Index

		if Waypoint.Action == Enum.PathWaypointAction.Jump then
			Humanoid.Jump = true
		end

		local MoveFinished = false
		local ReachedWaypoint = false

		local MoveConnection = Humanoid.MoveToFinished:Connect(function(Reached)
			MoveFinished = true
			ReachedWaypoint = Reached
		end)

		Humanoid:MoveTo(Waypoint.Position)

		--while not MoveFinished
		--	and not PathBlocked
		--	and TargetVersion == self.TargetVersion do

		--	if os.clock() - StartTime >= RepathInterval then
		--		RepathRequested = true
		--		break
		--	end

		--	task.wait(0.05)
		--end
		while not MoveFinished
			and not PathBlocked
			and TargetVersion == self.TargetVersion
			and not self.Stunned do
			if os.clock() - StartTime >= RepathInterval then
				RepathRequested = true
				break
			end

			task.wait(0.05)
		end
		MoveConnection:Disconnect()
		if RepathRequested or self.Stunned
			or PathBlocked
			or TargetVersion ~= self.TargetVersion then
			break
		end
		if not MoveFinished or not ReachedWaypoint then
			break
		end
		--MoveConnection:Disconnect()

		--if RepathRequested or PathBlocked or TargetVersion ~= self.TargetVersion then
		--	break
		--end

		--if not MoveFinished or not ReachedWaypoint then
		--	RepathRequested = true
		--	break
		--end

	end

	BlockedConnection:Disconnect()

	--if RepathRequested or PathBlocked or TargetVersion ~= self.TargetVersion then
		--print("Repathing or blocked")Humanoid:MoveTo(NPCroot.Position)
	--end

end

function NPC:StartChasing(Distance: number)

	if self.IsChasing or self.Stunned then return end
	self.IsChasing = true

	self.Target = nil
	self.TargetVersion = 0

	task.spawn(function()
		while self.Model and self.Model.Parent do

			local NearestPlayer = self:GetNearestPlayer(Distance)
			if NearestPlayer ~= self.Target then
				self.Target = NearestPlayer
				self.TargetVersion += 1
			end

			task.wait(DetectionInterval)
		end

		self.IsChasing = false
	end)

	task.spawn(function()

		while self.Model and self.Model.Parent do

			local Target = self.Target
			local Version = self.TargetVersion

			if self.Returning or self.Stunned then
				task.wait(0.1)
			elseif Target then
				self:PathFindToPlayer(Target, Version)
				--task.wait(0.2)
			else
				task.wait(0.1)
			end
		end
	end)
end

function NPC:CanAttack(Player: Player, Distance: number): boolean
	return self:CanDetectPlayer(Player, Distance, 0)
end


function NPC:StartAttackSequence()
	if self.IsAttacking or self.IsReturning or self.OnCooldown then return end

	self.IsAttacking = true

	task.spawn(function()
		while self.Model and self.Model.Parent and not self.Dead do

			if self.Stunned or self.IsReturning then
				task.wait(0.1)
			else
				local Target = self.Target
				if Target and self:CanAttack(Target, 10) and not self.OnCooldown then
					self.OnCooldown = true
					self:PlayAnimation("rbxassetid://92777911929022")
					local TargetToDamage = DetectHit(self.Model, DefaultHitboxSize)
					if not self.Stunned and TargetToDamage then
						TargetToDamage:TakeDamage(10)
					end
					task.wait(self.AttackCooldown)
					self.OnCooldown = false
				else
					task.wait(0.1)
				end
			end
		end
		self.IsAttacking = false
	end)
end

function NPC:SetStun(Duration: number)
	if not Duration or Duration <= 0 then return end

	self.StunVersion = (self.StunVersion or 0) + 1
	local CurrentStunVersion = self.StunVersion

	local Humanoid = self.Model and self.Model:FindFirstChildOfClass("Humanoid")
	if not self.Stunned and Humanoid then
		self.StunWalkSpeed = Humanoid.WalkSpeed
	end
	self.Stunned = true
	self.TargetVersion += 1
	if Humanoid then
		Humanoid.WalkSpeed = 0
		local Root = self.Model:FindFirstChild("HumanoidRootPart")
		if Root then
			Humanoid:MoveTo(Root.Position)
		end
	end
	task.delay(Duration, function()
		if self.StunVersion ~= CurrentStunVersion then return end
		self.Stunned = false
		if Humanoid and Humanoid.Parent then
			Humanoid.WalkSpeed = self.StunWalkSpeed or 16
		end
	end)
end

function NPC:PlayAnimation(ID: string)
	local Humanoid = self.Model and self.Model:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
	local Animation = Instance.new("Animation")
	Animation.AnimationId = ID
	local Track = Animator:LoadAnimation(Animation)
	Track.Priority = Enum.AnimationPriority.Action
	Track:Play()
	return Track
end
function NPC:Destroy()
	self.Dead = true
	local Zero = Vector3.new(0, 0, 0)
	local SizeIncrease = Vector3.new(0, 1, 1)
	local CoinClone = Coin:Clone()
	local Root = self.Model:FindFirstChild("HumanoidRootPart")
	local RootCFrame = Root.CFrame
	local UP = RootCFrame + Vector3.new(0, 10, 0)
	CoinClone.Parent = workspace
	CoinClone.Anchored = true
	CoinClone.Name = "Coin"
	CoinClone.CFrame = UP
	local PickUpSound = Coin:WaitForChild("PickUp")
	
	local DestructionTweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local SizeTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	local DestroyCoinInfo = TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
	for _, Part in self.Model:GetDescendants() do
		if Part:IsA("BasePart") then
			local DestructionTween = TweenService:Create(Part, DestructionTweenInfo, {CFrame = UP, Transparency = 1, Size = Zero})
			local GrowTween = TweenService:Create(CoinClone, SizeTweenInfo, {Size = CoinClone.Size + SizeIncrease})
			DestructionTween:Play()
			DestructionTween.Completed:Wait()
			PickUpSound:Play()
			GrowTween:Play()

		end
	end
	local ReturnTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local RetrunTween = TweenService:Create(CoinClone, ReturnTweenInfo, {CFrame = RootCFrame})
	RetrunTween:Play()
	RetrunTween.Completed:Wait()
	CoinClone.Ready.Value = true
	local Connection
	Connection = CoinClone.Touched:Connect(function(Hit)
		if not CoinClone.Ready.Value then return end
		CoinClone.Ready.Value = false

		local Character = Hit:FindFirstAncestorOfClass("Model")
		local Player = Character and Players:GetPlayerFromCharacter(Character)

		if not Player then return end
		local leaderstats = Player:FindFirstChild("leaderstats")
		if not leaderstats then return end
		local Coins = leaderstats:FindFirstChild("Coins")
		if not Coins then return end
		local PickUpTween = TweenService:Create(CoinClone, DestroyCoinInfo, {Size = Zero, Transparency = 1})
		Coins.Value += 15
		PickUpSound:Play()
		PickUpTween:Play()
		PickUpTween.Completed:Wait()

		CoinClone:Destroy()
		Connection:Disconnect()
	end)
	
	
	
    self.Target = nil
    self.TargetVersion += 1
    if not self.Model then return end
	local Model = self.Model
	ActiveNPCs[Model] = nil
	Model:Destroy()
	self.Name = nil
	self.Model = nil
end


return NPC
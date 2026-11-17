-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

-- Modules
local AttackTypes = require(ReplicatedStorage.Data.AttackTypes)
local States = require(ReplicatedStorage.Data.StateHandler)
local NormalAbilities = require(script.NormalAbilities)

-- Events
local Events = ReplicatedStorage.FunctionsAndEvents
local AttackEvent = Events.AttackEvent
local ParryEvent = Events.ParryEvent
local BlockEvent = Events.BlockEvent
local FrontDashEvent = Events.FrontDashEvent

-- Constants
local ATTACK = "ATTACK"
local PARRY = "PARRY"
local BLOCK = "BLOCK"
local DASH = "DASH"
local PROJECTILE = "PROJECTILE"
local ABILITY_BURST = "ABILITY_BURST"
local ABILITY_ENLARGE = "ABILITY_ENLARGE"
local ABILITY_HOMINGPROJECTILE = "ABILITY_HOMINGPROJECTILE"
local ABILITY_DEBOUNCE = 0.2
local BLOCK_ANIMATION_ID = "rbxassetid://92625753733833"
local M1_SOUND_ID = "rbxassetid://135187254016556"
local BLOCK_HOLD_TIME = 0.5

local player = Players.LocalPlayer


local function GetCameraYaw(Camera: Camera, Fallback: CFrame): CFrame
	local Look = Camera.CFrame.LookVector
	local Flat = Vector3.new(Look.X, 0, Look.Z)
	if Flat.Magnitude < 0.01 then return Fallback end
	return CFrame.lookAt(Vector3.zero, Flat)
end


local function GetDashDirectionName(LocalDirection: Vector3): string
	if math.abs(LocalDirection.Z) >= math.abs(LocalDirection.X) then
		return if LocalDirection.Z < 0 then "Front" else "Back"
	end
	return if LocalDirection.X > 0 then "Right" else "Left"
end

local Attacker = {}
Attacker.__index = Attacker

function Attacker.new(AttackType: string)
	local self = setmetatable({}, Attacker)

	self.AttackType = AttackType
	self.AttackConfig = AttackTypes.GetConfig(AttackType)
	assert(self.AttackConfig, "Unknown attack type: " .. tostring(AttackType))

	self.Ready = false
	self:SetupCharacter(player.Character or player.CharacterAdded:Wait())

	self.CharacterConnection = player.CharacterAdded:Connect(function(Character)
		self:SetupCharacter(Character)
	end)

	ContextActionService:BindAction(ATTACK, function(...)
		self:Attack(...)
	end, true, Enum.UserInputType.MouseButton1)

	ContextActionService:BindAction(PARRY, function(...)
		self:Parry(...)
	end, true, Enum.KeyCode.E)

	ContextActionService:BindAction(BLOCK, function(...)
		self:Block(...)
	end, true, Enum.KeyCode.F)

	ContextActionService:BindAction(DASH, function(...)
		self:Dash(...)
	end, true, Enum.KeyCode.Q)

	ContextActionService:BindAction(PROJECTILE, function(...)
		self:NormalProjectile(...)
	end, true, Enum.KeyCode.R)

	ContextActionService:BindAction(ABILITY_BURST, function(_, InputState)
		if InputState == Enum.UserInputState.Begin then
			self:UseProjectileAbility("Burst")
		end
	end, true, Enum.KeyCode.One)

	ContextActionService:BindAction(ABILITY_ENLARGE, function(_, InputState)
		if InputState == Enum.UserInputState.Begin then
			self:UseProjectileAbility("Enlarge")
		end
	end, true, Enum.KeyCode.Two)
	
	ContextActionService:BindAction(ABILITY_HOMINGPROJECTILE, function(_, InputState)
		if InputState == Enum.UserInputState.Begin then
			self:UseProjectileAbility("HomingProjectile")
		end
	end, true, Enum.KeyCode.Three)

	return self
end

function Attacker:SetupCharacter(Character: Model)
	self.Ready = false
	self.SetupId = (self.SetupId or 0) + 1
	local SetupId = self.SetupId

	local Humanoid = Character:WaitForChild("Humanoid")
	local Animator = Humanoid:WaitForChild("Animator")
	local RootPart = Character:WaitForChild("HumanoidRootPart")
	if self.SetupId ~= SetupId then return end 

	self.Character = Character
	self.Humanoid = Humanoid
	self.Animator = Animator
	self.RootPart = RootPart

	self.M1Sound = Instance.new("Sound")
	self.M1Sound.SoundId = M1_SOUND_ID
	self.M1Sound.Parent = RootPart

	self.Tracks = {}
	for Index, Hit in self.AttackConfig.Hits do
		local Animation = Instance.new("Animation")
		Animation.AnimationId = Hit.AnimationId
		local Track = Animator:LoadAnimation(Animation)
		Track.Priority = Enum.AnimationPriority.Action
		self.Tracks[Index] = Track
	end

	local BlockAnimation = Instance.new("Animation")
	BlockAnimation.AnimationId = BLOCK_ANIMATION_ID
	self.BlockTrack = Animator:LoadAnimation(BlockAnimation)
	self.BlockTrack.Priority = Enum.AnimationPriority.Action
	self.BlockTrack.Looped = false

	self.DashTracks = {}
	for Direction, Dash in self.AttackConfig.Dashes do
		if Dash.AnimationId ~= "" then
			local Animation = Instance.new("Animation")
			Animation.AnimationId = Dash.AnimationId
			local Track = Animator:LoadAnimation(Animation)
			Track.Priority = Enum.AnimationPriority.Action
			self.DashTracks[Direction] = Track
		end
	end


	self.HitIndex = 1
	self.LastAttack = -math.huge
	self.LastDashTimes = {}
	self.LastProjectileThrow = -math.huge
	self.LastAbilityPress = -math.huge
	self.BlockId = 0
	self.Attacked = false
	self.Parrying = false
	self.Blocking = false
	self.Dashing = false
	self.DashAttackTime = 0

	self.Ready = true
end

function Attacker:CanAct(): boolean
	return self.Ready
		and self.Humanoid.Health > 0
		and not States.ReturnState(player, "Stunned")
end

function Attacker:Attack(_ActionName, InputState)
	if InputState ~= Enum.UserInputState.Begin then return end
	if not self:CanAct() then return end
	if self.Attacked or self.Blocking then return end
	if self.Dashing and os.clock() < self.DashAttackTime then return end

	local Hits = self.AttackConfig.Hits

	if os.clock() - self.LastAttack > self.AttackConfig.ComboResetTime then
		self.HitIndex = 1
	end

	local Index = self.HitIndex
	local Hit = Hits[Index]

	self.Attacked = true
	task.delay(Hit.Cooldown, function()
		self.Attacked = false
	end)
	self.LastAttack = os.clock()
	self.HitIndex = Index % #Hits + 1 --mod

	self.Tracks[Index]:Play()
	self.M1Sound:Play()

	task.delay(Hit.HitDelay, function()
		AttackEvent:FireServer(self.AttackType, Index)
	end)
end

function Attacker:Parry(_ActionName, InputState)
	if InputState ~= Enum.UserInputState.Begin then return end
	if not self:CanAct() then return end
	if self.Attacked or self.Parrying or self.Blocking or self.Dashing then return end

	self.Parrying = true
	task.delay(self.AttackConfig.ParryCooldwon, function()
		self.Parrying = false
	end)

	ParryEvent:FireServer(self.AttackType)
end

function Attacker:Block(_ActionName, InputState)
	if InputState == Enum.UserInputState.Begin then
		if not self:CanAct() then return end
		if self.Blocking or self.Attacked or self.Dashing then return end

		self.Blocking = true
		self.BlockId += 1
		local BlockId = self.BlockId

		BlockEvent:FireServer(true)

		local Track = self.BlockTrack
		Track:Play()
		Track:AdjustSpeed(1)

		task.delay(BLOCK_HOLD_TIME, function()
			if self.Blocking and self.BlockId == BlockId then
				Track:AdjustSpeed(0)
			end
		end)

	elseif InputState == Enum.UserInputState.End then
		if not self.Blocking then return end

		self.Blocking = false
		local BlockId = self.BlockId

		BlockEvent:FireServer(false)

		local Track = self.BlockTrack
		Track:AdjustSpeed(-1)

		task.delay(Track.TimePosition, function()
			if not self.Blocking and self.BlockId == BlockId then
				Track:Stop()
			end
		end)
	end
end

function Attacker:Dash(_ActionName, InputState)
	if InputState ~= Enum.UserInputState.Begin then return end
	if not self:CanAct() then return end
	if self.Attacked or self.Blocking or self.Dashing then return end

	local Humanoid = self.Humanoid
	local RootPart = self.RootPart
	local Camera = workspace.CurrentCamera
	local CameraYaw = GetCameraYaw(Camera, CFrame.identity)


	local LocalDirection = Vector3.new(0, 0, -1) 
	local MoveDirection = Humanoid.MoveDirection
	if MoveDirection.Magnitude >= 0.1 then
		local Local = CameraYaw:VectorToObjectSpace(MoveDirection)
		LocalDirection = Vector3.new(Local.X, 0, Local.Z).Unit
	end

	local Direction = GetDashDirectionName(LocalDirection)
	local Dash = AttackTypes.GetDash(self.AttackType, Direction)
	if not Dash then return end

	local Now = os.clock()
	local LastDash = self.LastDashTimes[Direction]
	if LastDash and Now - LastDash < Dash.Cooldown then return end

	self.LastDashTimes[Direction] = Now
	self.Dashing = true
	self.DashAttackTime = Now + Dash.Time * (Dash.AttackWindow or 1)
	task.delay(Dash.Time, function()
		self.Dashing = false
	end)

	-- tell the server to start the dash
	FrontDashEvent:FireServer(self.AttackType, Direction)

	local DashTrack = self.DashTracks[Direction]
	if DashTrack then
		DashTrack:Play()
	end
	
	Humanoid.JumpHeight = 0

	if Dash.KeepFacing then
		local Position = RootPart.Position
		RootPart.CFrame = CFrame.lookAt(Position, Position + CameraYaw.LookVector)
		Humanoid.AutoRotate = false
		task.delay(Dash.Time, function()
			if Humanoid.Parent then
				Humanoid.AutoRotate = true
			end
		end)
	end

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = RootPart

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.MaxForce = math.huge
	LinearVelocity.VectorVelocity = CameraYaw:VectorToWorldSpace(LocalDirection) * Dash.Speed
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.Parent = RootPart

	Debris:AddItem(LinearVelocity, Dash.Time)
	Debris:AddItem(Attachment, Dash.Time)

	local EndTime = Now + Dash.Time
	local Connection
	Connection = RunService.RenderStepped:Connect(function()
		if os.clock() >= EndTime or not LinearVelocity.Parent then
			Connection:Disconnect()
			Humanoid.JumpHeight = 7.2
			return
		end
		CameraYaw = GetCameraYaw(Camera, CameraYaw)
		LinearVelocity.VectorVelocity = CameraYaw:VectorToWorldSpace(LocalDirection) * Dash.Speed
	end)
end

function Attacker:NormalProjectile(_ActionName, InputState)
	if InputState ~= Enum.UserInputState.Begin then return end
	if not self:CanAct() then return end
	if self.Attacked or self.Blocking then return end
	if self.Dashing and os.clock() < self.DashAttackTime then return end

	local ProjectileConfig = AttackTypes.GetProjectile(self.AttackType)
	if not ProjectileConfig then return end -- this attack type has no projectile

	local Now = os.clock()
	if Now - self.LastProjectileThrow < ProjectileConfig.Cooldown then return end
	self.LastProjectileThrow = Now

	NormalAbilities.ThrowProjectile(self.AttackType)
end

function Attacker:UseProjectileAbility(AbilityName: string)
	if not self:CanAct() then return end
	if not AttackTypes.GetAbility(self.AttackType, AbilityName) then return end 

	local Now = os.clock()
	if Now - self.LastAbilityPress < ABILITY_DEBOUNCE then return end
	self.LastAbilityPress = Now

	NormalAbilities.ActivateProjectileAbility(self.AttackType, AbilityName)
end

function Attacker:Destroy()
	ContextActionService:UnbindAction(ATTACK)
	ContextActionService:UnbindAction(PARRY)
	ContextActionService:UnbindAction(BLOCK)
	ContextActionService:UnbindAction(DASH)
	ContextActionService:UnbindAction(PROJECTILE)
	ContextActionService:UnbindAction(ABILITY_BURST)
	ContextActionService:UnbindAction(ABILITY_ENLARGE)
	ContextActionService:UnbindAction(ABILITY_HOMINGPROJECTILE)

	if self.CharacterConnection then
		self.CharacterConnection:Disconnect()
		self.CharacterConnection = nil
	end
end

return Attacker
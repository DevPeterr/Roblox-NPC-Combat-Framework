
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DamageBillboard = ReplicatedStorage
	:WaitForChild("UI")
	:WaitForChild("DamageBillboard")

local States = require(ReplicatedStorage.Data.StateHandler)
local NPC = require(script.Parent["NPC Handler"])

local HitBox = ReplicatedStorage:WaitForChild("HitBoxM1")

local HIT_WINDOW = 0.28           
local HITBOX_LINGER = 0.2         
local TOLERANCE = 0.15            
local MAX_PING_COMPENSATION = 0.3  
local DASH_HIT_DELAY = 0.2         
local BLOCK_FOV_DOT = 0.5         
local PARRY_HITBOX_SIZE = Vector3.new(5, 5, 5)
local PARRY_STUN_TIME = 2

local function ShowHitHighlight(Model: Model)
	local Highlight = Instance.new("Highlight")
	Highlight.Adornee = Model
	Highlight.FillColor = Color3.fromRGB(255, 70, 70)
	Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	Highlight.FillTransparency = 0.65
	Highlight.OutlineTransparency = 0
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Parent = Model
	local FadeTweenInfo = TweenInfo.new(
		0.25,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local FadeTween = TweenService:Create(Highlight, FadeTweenInfo, {
		FillTransparency = 1,
		OutlineTransparency = 1
	})
	FadeTween:Play()
	Debris:AddItem(Highlight, 0.3)
end

local function ShowDamageNumber(TargetRoot: BasePart, Damage: number)
	if not TargetRoot or Damage <= 0 then return end

	local Billboard = DamageBillboard:Clone()
	local Label = Billboard:FindFirstChildWhichIsA("TextLabel", true)

	if not Label then
		Billboard:Destroy()
		warn("DamageBillboard is missing a TextLabel!")
		return
	end
	local Offset = Vector3.new(
		math.random(-8, 8) / 10,
		3,
		math.random(-8, 8) / 10
	)
	Billboard.Adornee = TargetRoot
	Billboard.StudsOffsetWorldSpace = Offset
	Billboard.Parent = workspace

	Label.Text = string.format("%g", Damage)
	Label.TextColor3 = Color3.fromHSV(math.random(), 0.8, 1)
	local AnimationInfo = TweenInfo.new(
		0.7,
		Enum.EasingStyle.Cubic,
		Enum.EasingDirection.Out
	)
	local MoveTween = TweenService:Create(Billboard, AnimationInfo, {
		StudsOffsetWorldSpace = Offset + Vector3.new(0, 2, 0)
	})
	local FadeTween = TweenService:Create(Label, AnimationInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
	MoveTween:Play()
	FadeTween:Play()
	Debris:AddItem(Billboard, 0.8)
end


local AttackHandeler = {}

local LastAttack = {} 
local LastUse = {}   

Players.PlayerRemoving:Connect(function(player)
	LastAttack[player] = nil
	LastUse[player] = nil
end)


local function GetRoot(player: Player): BasePart?
	local Character = player.Character
	return Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function HasAnyState(player: Player, ...: string): boolean
	for _, StateKey in {...} do
		if States.ReturnState(player, StateKey) then
			return true
		end
	end
	return false
end


local function IsOnCooldown(player: Player, Key: string, Cooldown: number): boolean
	local Uses = LastUse[player]
	if not Uses then
		Uses = {}
		LastUse[player] = Uses
	end

	local Now = os.clock()
	local Last = Uses[Key]
	if Last and Now - Last < Cooldown - TOLERANCE then
		return true
	end

	Uses[Key] = Now
	return false
end


local function DetectHit(player: Player, HitBoxSize: Vector3): Humanoid?
	local Character = player.Character
	local Root = GetRoot(player)
	if not Character or not Root then return nil end

	local HitBoxClone = HitBox:Clone()
	HitBoxClone.Size = HitBoxSize
	HitBoxClone.Anchored = true
	HitBoxClone.CanCollide = false
	HitBoxClone.CanTouch = false
	HitBoxClone.Parent = workspace
	Debris:AddItem(HitBoxClone, HIT_WINDOW + HITBOX_LINGER)

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, HitBoxClone}

	local Checked = {} 
	local EndTime = os.clock() + HIT_WINDOW

	while os.clock() < EndTime and Root.Parent do
		local Ping = math.min(player:GetNetworkPing(), MAX_PING_COMPENSATION)
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

function AttackHandeler.IsAttackInBlockFov(AttackRoot: BasePart, BlockRoot: BasePart): boolean
	local Offset = AttackRoot.Position - BlockRoot.Position
	if Offset.Magnitude < 0.001 then return true end 

	return BlockRoot.CFrame.LookVector:Dot(Offset.Unit) >= BLOCK_FOV_DOT
end

local function IsBlocked(AttackerRoot: BasePart, EnemyPlayer: Player): boolean
	if not States.ReturnState(EnemyPlayer, "Blocking") then return false end

	local EnemyRoot = GetRoot(EnemyPlayer)
	return EnemyRoot ~= nil and AttackHandeler.IsAttackInBlockFov(AttackerRoot, EnemyRoot)
end



AttackHandeler.HasAnyState = HasAnyState
AttackHandeler.IsOnCooldown = IsOnCooldown


function AttackHandeler.DealDamage(Source: BasePart, Humanoid: Humanoid, Damage: number, StunTime: number?): boolean
	local AttackerModel = Source:FindFirstAncestorOfClass("Model")
	local AttackingPlayer = AttackerModel and Players:GetPlayerFromCharacter(AttackerModel)

	if AttackingPlayer then
		Damage += AttackingPlayer:GetAttribute("DamageBonus") or 0
	end
	local EnemyModel = Humanoid.Parent
	if not EnemyModel then return false end
	local TargetRoot = EnemyModel:FindFirstChild("HumanoidRootPart")
	local EnemyPlayer = Players:GetPlayerFromCharacter(EnemyModel)
	if EnemyPlayer then
		if States.ReturnState(EnemyPlayer, "Evading") then return false end
		if IsBlocked(Source, EnemyPlayer) then return false end

		local PreviousHealth = Humanoid.Health

		Humanoid:TakeDamage(Damage)

		local ActualDamage = PreviousHealth - Humanoid.Health

		if TargetRoot and ActualDamage > 0 then
			ShowDamageNumber(TargetRoot, ActualDamage)
			ShowHitHighlight(EnemyModel)
		end

		if StunTime and StunTime > 0 then
			States.SetStun(EnemyPlayer, true, StunTime, 0)
		end

		return true
	end
	local EnemyNPC = NPC.GetFromModel(EnemyModel)
	local PreviousHealth = Humanoid.Health
	Humanoid:TakeDamage(Damage)
	local ActualDamage = PreviousHealth - Humanoid.Health
	if TargetRoot and ActualDamage > 0 then
		ShowDamageNumber(TargetRoot, ActualDamage)
		ShowHitHighlight(EnemyModel)
	end
	if EnemyNPC and StunTime and StunTime > 0 then
		EnemyNPC:SetStun(0.13)
	end
	return true
end

function AttackHandeler.Damage(player: Player, Hit)
	local Humanoid = DetectHit(player, Vector3.new(table.unpack(Hit.HitBox)))
	if not Humanoid then return end

	local AttackerRoot = GetRoot(player)
	if not AttackerRoot then return end

	AttackHandeler.DealDamage(AttackerRoot, Humanoid, Hit.Damage, Hit.StunTime)
end


function AttackHandeler.Attack(player: Player, Hit)
	if HasAnyState(player, "Stunned", "Blocking", "DashLocked", "Parrying") then return end

	local Now = os.clock()
	local Last = LastAttack[player]
	if Last and Now - Last.Time < Last.Cooldown - TOLERANCE then return end
	LastAttack[player] = {Time = Now, Cooldown = Hit.Cooldown}

	States.SetState(player, "Attacking", true, Hit.Cooldown)
	AttackHandeler.Damage(player, Hit)
end


function AttackHandeler.Parry(player: Player, Config)
	if HasAnyState(player, "Stunned", "Blocking", "Attacking", "Dashing", "Parrying") then return end
	if IsOnCooldown(player, "Parry", Config.ParryCooldwon) then return end

	States.SetState(player, "Parrying", true, HIT_WINDOW)

	local Humanoid = DetectHit(player, PARRY_HITBOX_SIZE)
	if not Humanoid then return end

	local EnemyPlayer = Players:GetPlayerFromCharacter(Humanoid.Parent)
	if not EnemyPlayer then return end

	States.SetStun(EnemyPlayer, true, PARRY_STUN_TIME, 0)
end


function AttackHandeler.Block(player: Player, Value: boolean)
	if Value then
		if HasAnyState(player, "Stunned", "Attacking", "Dashing", "Blocking") then return end
		States.SetState(player, "Blocking", true)
	else
		States.SetState(player, "Blocking", false)
	end
end


function AttackHandeler.Dash(player: Player, Dash, Direction: string)
	if HasAnyState(player, "Stunned", "Blocking", "Attacking", "Dashing") then return end
	if IsOnCooldown(player, "Dash_" .. Direction, Dash.Cooldown) then return end

	local Character = player.Character
	States.SetState(player, "Dashing", true, Dash.Time)


	local LockTime = Dash.Time * (Dash.AttackWindow or 1) - TOLERANCE
	if LockTime > 0 then
		States.SetState(player, "DashLocked", true, LockTime)
	end


	if Dash.EvadeTime and Dash.EvadeTime > 0 then
		States.SetState(player, "Evading", true, Dash.EvadeTime)
	end

	if not Dash.Hits then return end 

	task.wait(Dash.Time + DASH_HIT_DELAY)


	if player.Character ~= Character then return end
	if States.ReturnState(player, "Stunned") then return end

	if States.ReturnState(player, "Attacking") then return end

	local Humanoid = DetectHit(player, Vector3.new(table.unpack(Dash.HitBox)))
	if not Humanoid then return end

	local AttackerRoot = GetRoot(player)
	if not AttackerRoot then return end

	AttackHandeler.DealDamage(AttackerRoot, Humanoid, Dash.Damage, nil)
end

return AttackHandeler
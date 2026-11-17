local TW = game:GetService("TweenService")
local Players = game:GetService("Players")


local EnlrageTween = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)
local TravelTween = TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0)

local ProjectileHandler = require(script.Parent)

local TWO_PI = math.pi * 2

local function GetNearestTarget(Projectile: BasePart, Distance: number, Owner: Player): Model?
	local NearestTarget = nil
	local ShortestDistance = Distance

	local function CheckTarget(Character: Model?)
		if not Character then return end

		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local Root = Character:FindFirstChild("HumanoidRootPart")

		if not Humanoid or Humanoid.Health <= 0 then return end
		if not Root or not Root:IsA("BasePart") then return end

		local CurrentDistance = (Root.Position - Projectile.Projectile.Position).Magnitude

		if CurrentDistance < ShortestDistance then
			ShortestDistance = CurrentDistance
			NearestTarget = Character
		end
	end

	for _, Player in Players:GetPlayers() do
		if Player ~= Owner then
			CheckTarget(Player.Character)
		end
	end

	for _, Object in workspace:GetChildren() do
		if Object:IsA("Model") and not Players:GetPlayerFromCharacter(Object) then
			CheckTarget(Object)
		end
	end

	return NearestTarget
end

local function Burst(Projectile: Instance, Owner: Player, Config)
	local Pivot = Projectile:GetPivot()
	local Origin = Pivot.Position


	local Look = Pivot.LookVector
	local Start = Vector3.new(Look.X, 0, Look.Z)
	Start = if Start.Magnitude > 0.01 then Start.Unit else Vector3.new(0, 0, -1)

	Projectile:Destroy()

	local Slice = TWO_PI / Config.Bullets
	for Index = 0, Config.Bullets - 1 do
		local Direction = CFrame.fromAxisAngle(Vector3.yAxis, Index * Slice) * Start
		ProjectileHandler.Launch(Owner, Origin + Direction * Config.SpawnRadius, Direction, Config, nil)
	end
end

ProjectileHandler.Abilities.Burst = Burst



local function Enlarge(Projectile: Instance, Owner: Player, Config)

	local Factor = Instance.new("NumberValue")
	Factor.Value = 1

	if Projectile:IsA("Model") then
		local StartScale = Projectile:GetScale()
		Factor.Changed:Connect(function(Value)
			if not Projectile.Parent then return end
			Projectile:ScaleTo(StartScale * Value)
		end)
	else
		local StartSize = Projectile.Size
		Factor.Changed:Connect(function(Value)
			if not Projectile.Parent then return end
			Projectile.Size = StartSize * Value
		end)
	end

	local Tween = TW:Create(Factor, EnlrageTween, {Value = Config.Scale})
	Tween.Completed:Connect(function()
		Factor:Destroy()
	end)
	Tween:Play()


	Projectile:SetAttribute("Damage", Config.Damage)
	Projectile:SetAttribute("StunTime", Config.StunTime)


	local Primary = if Projectile:IsA("Model") then Projectile.PrimaryPart else Projectile
	local LinearVelocity = Primary and Primary:FindFirstChildOfClass("LinearVelocity")
	if LinearVelocity and LinearVelocity.VectorVelocity.Magnitude > 0 then
		LinearVelocity.VectorVelocity = LinearVelocity.VectorVelocity.Unit * Config.Speed
	end
end

ProjectileHandler.Abilities.Enlarge = Enlarge

local function HomingProjectile(Projectile: BasePart, Owner: Player, Config)
	local EndTime = os.clock() + 10

	while os.clock() < EndTime and Projectile.Parent do
		local Target = GetNearestTarget(Projectile, 30, Owner)

		if Target then
			local Root = Target:FindFirstChild("HumanoidRootPart")

			if Root and Root:IsA("BasePart") then
				local Tween = TW:Create(
					Projectile.Projectile,
					TravelTween,
					{Position = Root.Position}
				)

				Tween:Play()
				Tween.Completed:Wait()
			end
		else
			task.wait(0.1)
		end
	end
end
ProjectileHandler.Abilities.HomingProjectile = HomingProjectile


return {Burst = Burst, Enlarge = Enlarge, HomingProjectile = HomingProjectile}
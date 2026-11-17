

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local StatesHandler = {}

local IS_SERVER = RunService:IsServer()
local PREFIX = "State_"
local DEFAULT_WALKSPEED = 16
local BLOCK_WALKSPEED = 5

local TokenCounter = 0
local Tokens = {}  
local StunEnd = {}  
local StunSpeed = {} 

local function ServerOnly(FunctionName: string): boolean
	if IS_SERVER then return true end
	warn("CombatStateHandler." .. FunctionName .. " can only be called from the server")
	return false
end

local function ApplyWalkSpeed(plr: Player)
	local Character = plr.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return end

	local Speed = DEFAULT_WALKSPEED
	if plr:GetAttribute(PREFIX .. "Stunned") then
		Speed = StunSpeed[plr] or 0
	elseif plr:GetAttribute(PREFIX .. "Blocking") then
		Speed = BLOCK_WALKSPEED
	end
	Humanoid.WalkSpeed = Speed
end


function StatesHandler.ReturnState(plr: Player, StateKey: string)
	return plr:GetAttribute(PREFIX .. StateKey)
end

function StatesHandler.ReturnStates(plr: Player)
	local Result = {}
	for Name, Value in plr:GetAttributes() do
		if string.sub(Name, 1, #PREFIX) == PREFIX then
			Result[string.sub(Name, #PREFIX + 1)] = Value
		end
	end
	return Result
end



function StatesHandler.SetState(plr: Player, StateKey: string, Value: any, Duration: number?)
	if not ServerOnly("SetState") then return end

	local Name = PREFIX .. StateKey
	plr:SetAttribute(Name, Value or nil) 

	TokenCounter += 1
	local Token = TokenCounter
	local PlayerTokens = Tokens[plr]
	if not PlayerTokens then
		PlayerTokens = {}
		Tokens[plr] = PlayerTokens
	end
	PlayerTokens[StateKey] = Token

	if Value and type(Duration) == "number" then
		task.delay(Duration, function()
			local Current = Tokens[plr]
			if Current and Current[StateKey] == Token then
				plr:SetAttribute(Name, nil)
				ApplyWalkSpeed(plr)
			end
		end)
	end

	ApplyWalkSpeed(plr)
end

function StatesHandler.RemoveState(plr: Player, StateKey: string?)
	if not ServerOnly("RemoveState") then return end

	if StateKey then
		if StateKey == "Stunned" then
			StunEnd[plr] = nil
			StunSpeed[plr] = nil
		end
		StatesHandler.SetState(plr, StateKey, false)
		return
	end


	for Name in plr:GetAttributes() do
		if string.sub(Name, 1, #PREFIX) == PREFIX then
			plr:SetAttribute(Name, nil)
		end
	end
	Tokens[plr] = nil
	StunEnd[plr] = nil
	StunSpeed[plr] = nil
	ApplyWalkSpeed(plr)
end

function StatesHandler.Clearall()
	if not ServerOnly("Clearall") then return end
	for _, plr in Players:GetPlayers() do
		StatesHandler.RemoveState(plr)
	end
end


function StatesHandler.SetStun(plr: Player, Value: boolean, Duration: number?, StunWalkSpeed: number?)
	if not ServerOnly("SetStun") then return end
	if not plr then return end

	if Value then
		local EndTime = math.max(StunEnd[plr] or 0, os.clock() + (Duration or 0))
		StunEnd[plr] = EndTime
		StunSpeed[plr] = StunWalkSpeed or 0
		StatesHandler.SetState(plr, "Stunned", true, EndTime - os.clock())
	else
		StatesHandler.RemoveState(plr, "Stunned")
	end
end



if IS_SERVER then
	local function OnPlayerAdded(plr: Player)
		plr.CharacterAdded:Connect(function()
			StatesHandler.RemoveState(plr)
		end)
	end

	Players.PlayerAdded:Connect(OnPlayerAdded)
	for _, plr in Players:GetPlayers() do
		OnPlayerAdded(plr)
	end

	Players.PlayerRemoving:Connect(function(plr)
		Tokens[plr] = nil
		StunEnd[plr] = nil
		StunSpeed[plr] = nil
	end)
end

return StatesHandler

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PurchaseEvent = ReplicatedStorage.FunctionsAndEvents:WaitForChild("MerchantPurchase")

local CurrentGui

local function ShowPopup(Message, IsConfirmation)
	if CurrentGui then
		CurrentGui:Destroy()
	end

	local Gui = Instance.new("ScreenGui")
	Gui.Name = "MerchantGui"
	Gui.ResetOnSpawn = false
	Gui.Parent = Player:WaitForChild("PlayerGui")
	CurrentGui = Gui

	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.fromOffset(350, 160)
	Frame.Position = UDim2.fromScale(0.5, 0.5)
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Parent = Gui

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -20, 0, 75)
	Label.Position = UDim2.fromOffset(10, 5)
	Label.Text = Message
	Label.TextScaled = true
	Label.BackgroundTransparency = 1
	Label.Parent = Frame

	local function CreateButton(Text, Position, Callback)
		local Button = Instance.new("TextButton")
		Button.Size = UDim2.fromOffset(140, 45)
		Button.Position = Position
		Button.Text = Text
		Button.TextScaled = true
		Button.Parent = Frame
		Button.Activated:Connect(Callback)
		return Button
	end

	if IsConfirmation then
		CreateButton("Yes", UDim2.fromOffset(25, 100), function()
			PurchaseEvent:FireServer("Confirm")
			Gui:Destroy()
		end)

		CreateButton("No", UDim2.fromOffset(185, 100), function()
			PurchaseEvent:FireServer("Cancel")
			Gui:Destroy()
		end)
	else
		CreateButton("OK", UDim2.fromOffset(105, 100), function()
			Gui:Destroy()
		end)
	end
end

PurchaseEvent.OnClientEvent:Connect(function(Action, Message)
	if Action == "Ask" then
		ShowPopup("Hello Traveller, Would you like to buy an upgrade for 10 coins?", true)

	elseif Action == "Message" then
		ShowPopup(Message, false)
	end
end)

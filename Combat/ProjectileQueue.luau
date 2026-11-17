

local ProjectileQueue = {}
ProjectileQueue.__index = ProjectileQueue

function ProjectileQueue.new(IsValid: ((any) -> boolean)?)
	local self = setmetatable({}, ProjectileQueue)

	self.Items = {}
	self.Head = 1
	self.Tail = 0
	self.IsValid = IsValid

	return self
end


function ProjectileQueue:Prune()
	local IsValid = self.IsValid
	if not IsValid then return end

	local Valid = {}
	for Index = self.Head, self.Tail do
		local Item = self.Items[Index]
		if IsValid(Item) then
			table.insert(Valid, Item)
		end
	end

	self.Items = Valid
	self.Head = 1
	self.Tail = #Valid
end

function ProjectileQueue:Enqueue(Item: any)
	self.Tail += 1
	self.Items[self.Tail] = Item
end


function ProjectileQueue:Dequeue(): any?
	self:Prune()
	if self.Tail < self.Head then return nil end

	local Item = self.Items[self.Head]
	self.Items[self.Head] = nil
	self.Head += 1

	if self.Tail < self.Head then 
		self.Head = 1
		self.Tail = 0
	end

	return Item
end


function ProjectileQueue:Peek(): any?
	self:Prune()
	if self.Tail < self.Head then return nil end
	return self.Items[self.Head]
end

function ProjectileQueue:Size(): number
	self:Prune()
	return self.Tail - self.Head + 1
end


function ProjectileQueue:Clear(): {any}
	self:Prune()

	local Remaining = {}
	for Index = self.Head, self.Tail do
		table.insert(Remaining, self.Items[Index])
	end

	self.Items = {}
	self.Head = 1
	self.Tail = 0

	return Remaining
end

return ProjectileQueue
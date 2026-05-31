local Signal = require(script.Signal)
local Utils = require(script.Utils)
local Types = require(script.Types)
local Cnums = require(script.Cnums)

type Quest = Types.Quest
type QuestInternal = Types.QuestInternal
type Message = string
type Cnums = Cnums.Cnums
type Signal<F> = Signal.Signal<F>

type CompletionState = index<Cnums, "CompletionState">

local QuestModule = {}

local Quest = {} :: QuestInternal
Quest.__index = Quest

function QuestModule.new(maxProg: number, id: string?, parent: Quest?, weight: number?): Quest
	
	local self = setmetatable({
		Id = id,
		Progress = 0,
		MaxProgress = maxProg,
		
		Children = {},
		Parent = parent,
		
		Weight = weight or 1,
		
		Locked = false,
		
		Completed = Signal.new(),
		ProgressChanged = Signal.new(),
		ChildAdded = Signal.new(),
		ChildRemoved = Signal.new(),
		Destroyed = Signal.new()
		
	} :: Quest, Quest)
	
	local displayed = Utils.readOnly(self) :: Quest
		
	self._internal = self
	self._external = displayed
	
	self._incrementedProgress = 0
	
	self._boundMessages = {}
	self._boundSignals = {}
	
	return displayed
end

function Quest:_updateParent(parent: Quest?)
	self = self._internal

	local oldParent = self.Parent
	self.Parent = parent

	self.ParentChanged:Fire(oldParent, parent)
end

-- Internal function for when progress changes
function Quest:_handleProgressChange(msg: Message?)
	self = self._internal
	
	if self.Progress >= self.MaxProgress then
		self:Complete(Cnums.CompletionState.Successm, msg)
		
	end
end

function Quest:_recalculateProgress()
	self = self._internal
	
	local childProgress = 0
	
	for _, child in self.Children do
		childProgress += child.Completed and child.Weight or 0
		
	end
	
	local oldProgress = self.Progress
	
	self.Progress = childProgress + self._incrementedProgress
	
	if oldProgress ~= self.Progress then
		self.ProgressChanged:Fire(oldProgress, self.Progress)
	end
	
	self:_handleProgressChange()
end

function Quest:_cleanUp()
	local self = self._internal
	
	for msg, callback in self._boundMessages do
		self._boundMessages[msg] = nil
	end
	
	for _, conn in self._boundSignals do
		conn:Disconnect()
	end
	
	local internal, external = self._internal, self._external
	
	setmetatable(internal, nil)
	setmetatable(external, nil)
	
	self = nil
	
	return
end

-- Always use this to change the progress value
function Quest:Increment(amount: number, msg: Message?): number
	self = self._internal
	
	local oldVal = self.Progress
	self.Progress += amount
	
	self._incrementedProgress += amount
	
	self.ProgressChanged:Fire(oldVal, self.Progress, msg)
	
	self:_handleProgressChange(msg) -- Does not use _recalculateProgress to avoid extra calculations
	
	return oldVal
end

function Quest:Complete(completionState: CompletionState, msg: Message?)
	self = self._internal
	
	if self.LockOnCompletion then
		self:Lock(`Quest {self.Id} locked as LockOnCompletion was true when completion occured`)
	end
	
	self.Parent:_recalculateProgress()
	
	self.Completed:Fire(completionState, msg)
end

-- Also recursively destroys all children
function Quest:Destroy(msg: Message?)
	self = self._internal
	
	self:Lock(`Quest {self.Id} locked for deletion`)
	
	self.Parent:RemoveChildren(table.find(self.Parent.Children, self))
	
	self.Destroyed:Fire(msg)
	
	for _, child in self.Children do
		child:Destroy()
	end
	
	self._cleanUp()
end

function Quest:RemoveChildren(index: number | {number}): (Quest? | {Quest?})
	self = self._internal
	
	if typeof(index) == "number" then
		local removed = table.remove(self.Children, index) :: Quest?
		
		if not removed then
			warn(`Unable to remove child at index {index} because there are only {#self.Children} children`)
		else
			
			removed:_updateParent(nil)
		end
		
		self.ChildRemoved:Fire(removed)
		
		self:_recalculateProgress()
		
		return removed
	end
	
	table.sort(index, function(a, b) return a > b end)
	
	local removed = {}
	for _, i in index do
		table.insert(removed, self:RemoveChildren(i))
	end
	
	return removed
end

function Quest:AddChildren(item: Quest | {Quest}): (Quest | {Quest})
	self = self._internal
	
	if typeof(item) ~= "table" then
		table.insert(self.Children, item)
		
		self.ChildAdded:Fire(item)
		
		item:_updateParent(self._external)
		
		self:_recalculateProgress()
		
		return item
	end
	
	for _, i in item do
		table.insert(self.Children, i)

		self.ChildAdded:Fire(i)
		
		item:_updateParent(self._external)
		
		self:_recalculateProgress()
	end
	
	return item
end

function Quest:BindToMessage(msg: Message, callback: (...any?) -> ()): Quest
	self = self._internal
	
	if not self._boundMessages[msg] then
		self._boundMessages[msg] = {}
	end
	
	table.insert(self._boundMessages[msg], callback)
end

function Quest:BindToSignal<F>(signal: Signal<F>, callback: (F) -> ()): Quest
	self = self._internal
	
	table.insert(self._boundSignals, signal:Connect(callback))
end

function Quest:ToggleLockOnCompletion(value: boolean?): Quest
	self = self._internal
	
	self.LockOnCompletion = if value ~= nil then value else not self.LockOnCompletion
	
	return self._external
end

function Quest:Lock(reason: string?): Quest
	self = self._internal
		
	self.Locked = true
	
	self._internal = Utils.readOnly(self._internal, reason or `Quest {self.Id} locked for unspecified reasons`)
	
	return self._external
end

return QuestModule

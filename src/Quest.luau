--!strict

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
QuestModule.CNums = Cnums 
-- Yeah I don't really know why N wasn't capitalized in here, makes more sense for it to be capitalized externally though

local linkHead: QuestInternal? = nil
local linkTail: QuestInternal? = nil

local increment: number = 0

-- Quest Class
local Quest = {} :: QuestInternal
Quest.__index = Quest

-- Constructor for the Quest class
function QuestModule.new(maxProg: number?, id: string?, parent: Quest?, weight: number?): Quest
	
	increment += 1
	
	local self = setmetatable({
		Id = id or "Unamed Quest "..increment,
		Progress = 0,
		MaxProgress = maxProg or 100,
		
		Children = {},
		Parent = parent,
		
		Weight = weight or 1,
		IsComplete = Cnums.CompletionState.InProgress,
		
		Locked = false,
		LockOnComplete = false,
		
		Completed = Signal.new<<(completionState: CompletionState, msg: Message?) -> ()>>(),
		ProgressChanged = Signal.new<<(initial: number, final: number, msg: Message?) -> ()>>(),
		ChildAdded = Signal.new<<(child: any) -> ()>>(),
		ChildRemoved = Signal.new<<(child: any) -> ()>>(),
		ParentChanged = Signal.new<<(old: any?, new: any?) -> ()>>(),
		Destroyed = Signal.new<<(old: any?, new: any?) -> ()>>()
		
	}, Quest) :: QuestInternal
	
	
	local displayed = Utils.readOnly(self) :: Quest
	
	self._internal = self
	self._external = displayed :: QuestInternal
	
	self._incrementedProgress = 0
	
	self._boundMessages = {}
	self._boundSignals = {}
	
	if not linkHead then
		linkHead = self
		linkTail = self
	else
		(linkTail :: QuestInternal)._next = self
		self._prev = linkTail
		
		linkTail = self
	end
		
	if parent then
		parent:AddChildren(displayed)
	end
	
	return displayed
end

function Quest:_removeFromDLL()
	self = self._internal
	
	local prev, nex = self._prev, self._next
	
	if prev then -- Not Head
		prev._next = nex
		
		if nex then -- Center
			nex._prev = prev
		else -- Tail
			linkTail = prev
		end
	else
		if nex then -- Head
			nex._prev = prev
			
			linkHead = nex
		else -- Head & Tail
			linkTail = nil
			linkHead = nil
		end
	end
end

function Quest:_receiveMessage(msg: Message, ...: any?)
	self = self._internal
	
	local boundFunctions = self._boundMessages[msg]
	
	if not boundFunctions then return end
	
	for _, fn in boundFunctions do
		fn(self, ...)
	end
end

function Quest:_updateParent(parent: Quest?)
	self = self._internal

	local oldParent = self.Parent
	self.Parent = parent :: QuestInternal?

	self.ParentChanged:Fire(oldParent, parent)
end

-- Internal function for when progress changes
function Quest:_handleProgressChange(msg: Message?)
	self = self._internal
	
	self.IsComplete = Cnums.CompletionState.InProgress
	
	if self.Progress >= self.MaxProgress then
		self:Complete(Cnums.CompletionState.Success, msg)
		
	end
	
end

function Quest:_recalculateProgress()
	self = self._internal
	
	local childProgress = 0
	
	for _, child in self.Children do
		childProgress += child.IsComplete == Cnums.CompletionState.Success and child.Weight or 0
		
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
	
	self:_removeFromDLL()
	
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

-- Always use this to change the progress value.
function Quest:Increment(amount: number?, msg: Message?): QuestInternal
	self = self._internal
	
	local oldVal = self.Progress
	self.Progress += amount or 1
	
	self._incrementedProgress += amount or 1
	
	self.ProgressChanged:Fire(oldVal, self.Progress, msg)
	
	self:_handleProgressChange(msg) -- Does not use _recalculateProgress to avoid extra calculations
	
	return self._external
end

function Quest:Complete(completionState: CompletionState, msg: Message?)
	self = self._internal
	
	self.IsComplete = completionState
	
	if self.LockOnCompletion then
		self:Lock(`Quest {self.Id} locked as LockOnCompletion was true when completion occured`)
	end
	
	if self.Parent then
		self.Parent:_recalculateProgress()
	end
	
	self.Completed:Fire(completionState, msg)
end

-- Also recursively destroys all children
function Quest:Destroy(msg: Message?)
	--[[
	This function does forceful removal that does not
	respect the Locked property or the proxy table 
	which attempts to enforce it.
	
	This is done as destruction is seen to be of the
	highest priority, and should not be able to be
	stopped by anything else.
	
	I couldn't figure out how to get the freaking darn
	types to work with this guhhhhh
	]]
	self = self._internal
	
	self:Lock(`Quest {self.Id} locked for deletion`)
	
	local trueSelf = getmetatable(self._external).__index :: QuestInternal
	if self.Parent then
		-- Forcefully remove Self from Parent
		
		local trueParent = getmetatable(self.Parent._external).__index :: QuestInternal
		
		local removed = table.remove(trueParent.Children, table.find(trueParent.Children, self._external))
		
		if removed and not trueParent.Locked then
			trueParent.ChildRemoved:Fire(removed)
			trueParent:_recalculateProgress()
		end
		
		trueSelf.Parent = nil
	end
	
	self.Destroyed:Fire(msg)
	
	for _, child in self.Children do
		child:Destroy(msg)
	end
	
	self:_cleanUp()
end

function Quest:RemoveChildren(index: number | {number}): QuestInternal
	self = self._internal
	
	if typeof(index) == "number" then
		local removed = table.remove(self.Children, index) :: QuestInternal?
		
		if not removed then
			warn(`Unable to remove child at index {index} because there are only {#self.Children} children`)
		else
			
			removed:_updateParent(nil)
		end
		
		self.ChildRemoved:Fire(removed)
		
		self:_recalculateProgress()
		
	elseif index then
			
		table.sort(index, function(a: number, b: number) return a > b end)
	
		local removed = {}
		for _, i in index do
			table.insert(removed, self:RemoveChildren(i) :: Quest?)
		end
		
	else
		
		local removed = {}
		for i = #self.Children, 1, -1 do
			table.insert(removed, self:RemoveChildren(i) :: Quest?)
		end
		
	end
	
	return self._external
end

function Quest:AddChildren(item: QuestInternal, ...: QuestInternal): QuestInternal
	self = self._internal
	
	local items = {...}
	table.insert(items, item)	
	
	for _, i in items do
		table.insert(self.Children, i)

		self.ChildAdded:Fire(i)
		
		i:_updateParent(self._external)
		
		self:_recalculateProgress()
	end
	
	return self._external
end

function Quest:BindToMessage(msg: Message, callback: (self: QuestInternal, ...any?) -> ()): QuestInternal
	self = self._internal
	
	if not self._boundMessages[msg] then
		self._boundMessages[msg] = {}
	end
	
	table.insert(self._boundMessages[msg], callback)
	
	return self._external
end

function Quest:BindToSignal<F>(signal: Signal<F>, callback: (F) -> ()): QuestInternal
	self = self._internal
	
	table.insert(self._boundSignals, signal:Connect(callback))
	
	return self._external
end

function Quest:ToggleLockOnCompletion(value: boolean?): QuestInternal
	self = self._internal
	
	self.LockOnCompletion = if value ~= nil then value else not self.LockOnCompletion
	
	return self._external
end

function Quest:Lock(reason: string?): QuestInternal
	if self.Locked then
		return self._external
	end
	
	self = self._internal
		
	self.Locked = true
	
	self._internal = Utils.readOnly(self._internal, reason or `Quest {self.Id} locked for unspecified reasons`) :: QuestInternal
	
	return self._external
end

-- Module Functions

function QuestModule.SendMessage(msg: Message, ...: any?)
	
	local head = linkHead
	
	while head do
		head:_receiveMessage(msg, ...)
		
		head = head._next
	end
end

--[[
Quest Structure:

--------------------------------------
Not Locked:
Proxy > >	True Object	<	<
	^		/		  \		 ^
	^.external		.internal^

---------------------------------------
Locked:
Proxy > >	True Object	< < Proxy
	^		/		  \		 ^
	^.external		.internal^


Noting this down since I thought it was a simple double layered proxy for a while
]]

return QuestModule

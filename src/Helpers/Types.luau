--!strict

local Signal = require(script.Parent.Signal)
local Cnums = require(script.Parent.Cnums)

type Signal<F> = Signal.Signal<F>
type Cnums = Cnums.Cnums

type CompletionState = index<Cnums, "CompletionState">

type Message = string

export type Quest = {
	Id: string?,
	Progress: number,
	MaxProgress: number,

	Weight: number?, -- How much its completion contributes to its parent's progress
	IsComplete: CompletionState,

	Locked: boolean,
	LockOnCompletion: boolean,

	Completed: Signal<(completionState: CompletionState, msg: Message?) -> ()>,
	ProgressChanged: Signal<(initial: number, final: number, msg: Message?) -> ()>,
	ChildAdded: Signal<(child: any) -> ()>, -- Named signal implementation cannot support recursive types
	ChildRemoved: Signal<(child: any) -> ()>, -- All signals with generic type including signals must instead be typed as any
	ParentChanged: Signal<(old: any?, new: any?) -> ()>, --Same as above
	Destroyed: Signal<(msg: Message?) -> ()>,
	
	Children: {Quest?},
	Parent: Quest?,
	
	-- Changes Progress by Amount (Amount is defaulted to 1)
	Increment: typeof(function(self: Quest, amount: number?, msg: Message?): Quest return 0 end),
	
	-- Completes the Quest without editing Progress or calling _handleProgressChange
	Complete: typeof(function(self: Quest, completionState: CompletionState, msg: Message?) end), 
	
	-- Man I think most of these functions are pretty self-explanatory so I'm not gonna bother annotating the rest
	
	Destroy: (self: Quest, msg: Message?) -> (),
	RemoveChildren: (self: Quest, index: number | {number} | nil) -> (Quest),
	AddChildren: (self: Quest, item: Quest, ...Quest) -> (Quest),
	BindToMessage: (self: Quest, msg: Message, callback: (self: Quest, ...any?) -> ()) -> (Quest),
	BindToSignal: <F>(self: Quest, signal: Signal<F>, callback: (F) -> ()) -> (Quest),
	ToggleLockOnCompletion: (self: Quest, value: boolean?) -> (Quest),
	Lock: (self: Quest, reason: string?) -> (Quest)
}

export type QuestInternal =  {
	_internal: QuestInternal,
	_external: QuestInternal,
	
	_incrementedProgress: number,
			
	_boundMessages: {[Message]: {(...any?) -> ()}},
	_boundSignals: {Signal.Connection},
	
	_receiveMessage: (self: QuestInternal, msg: Message, ...any?) -> (),
	
	_updateParent: (self: QuestInternal, parent: QuestInternal?) -> (),

	_handleProgressChange: (self: QuestInternal, msg: Message?) -> (),
	_recalculateProgress: (self: QuestInternal) -> (),
	
	_cleanUp: (self: QuestInternal) -> (),
	
	-- Doubly Linked List structure for easy removal --
	
	_prev: QuestInternal?,
	_next: QuestInternal?,
	_removeFromDLL: (self: QuestInternal) -> (),
	
	--[[
	So it turns out we must completely redefine Quest 
	inside QuestInternal in order to keep them named
	if we wish to redefine certain parts of Quest for
	the ease of use
	]]--
	
	-- Redefine Quest so that we get access to internal values inside class definition --
	
	Id: string?,
	Progress: number,
	MaxProgress: number,

	Weight: number?, -- How much its completion contributes to its parent's progress
	IsComplete: CompletionState,

	Locked: boolean,
	LockOnCompletion: boolean,

	Completed: Signal<(completionState: CompletionState, msg: Message?) -> ()>,
	ProgressChanged: Signal<(initial: number, final: number, msg: Message?) -> ()>,
	ChildAdded: Signal<(child: any) -> ()>, -- Named signal implementation cannot support recursive types
	ChildRemoved: Signal<(child: any) -> ()>, -- All signals with generic type including signals must instead be typed as any
	ParentChanged: Signal<(old: any?, new: any?) -> ()>, --Same as above
	Destroyed: Signal<(msg: Message?) -> ()>,

	Children: {QuestInternal?},
	Parent: QuestInternal?,

	Increment: (self: QuestInternal, amount: number?, msg: Message?) -> (QuestInternal),
	Complete: (self: QuestInternal, completionState: CompletionState, msg: Message?) -> (),
	Destroy: (self: QuestInternal, msg: Message?) -> (),
	RemoveChildren: (self: QuestInternal, index: number | {number} | nil) -> (QuestInternal),
	AddChildren: (self: QuestInternal, item: QuestInternal, ...QuestInternal) -> (QuestInternal),
	BindToMessage: (self: QuestInternal, msg: Message, callback: (self: QuestInternal, ...any?) -> ()) -> (QuestInternal),
	BindToSignal: <F>(self: QuestInternal, signal: Signal<F>, callback: (F) -> ()) -> (QuestInternal),
	ToggleLockOnCompletion: (self: QuestInternal, value: boolean?) -> (QuestInternal),
	Lock: (self: QuestInternal, reason: string?) -> (QuestInternal),
	
	-- Metatable for the class --
	__index: QuestInternal
}

return nil

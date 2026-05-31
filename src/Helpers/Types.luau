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

	Children: {Quest?},
	Parent: Quest?,
	
	Weight: number?, -- How much its completion contributes to its parent's progress
	
	Locked: boolean,
	LockOnCompletion: boolean,

	Completed: Signal<(completionState: CompletionState, msg: Message?) -> ()>,
	ProgressChanged: Signal<(initial: number, final: number, msg: Message?) -> ()>,
	ChildAdded: Signal<(child: any) -> ()>, -- Named signal implementation cannot support recursive types
	ChildRemoved: Signal<(child: any) -> ()>, -- All signals with generic type including signals must instead be typed as any
	ParentChanged: Signal<(old: any?, new: any?) -> ()>, --Same as above
	Destroyed: Signal<(msg: Message?) -> ()>,
	
	Increment: (self: Quest, amount: number, msg: Message?) -> (number),
	Complete: (self: Quest, completionState: CompletionState, msg: Message?) -> (),
	Destroy: (self: Quest, msg: Message?) -> (),
	RemoveChildren: (self: Quest, index: number | {number}) -> (Quest? | {Quest?}),
	AddChildren: (self: Quest, item: Quest | {Quest}) -> (Quest | {Quest}),
	BindToMessage: (self: Quest, msg: Message, callback: (...any?) -> ()) -> (Quest),
	BindToSignal: <F>(self: Quest, signal: Signal<F>, callback: (F) -> ()) -> (Quest),
	ToggleLockOnCompletion: (self: Quest, value: boolean?) -> (Quest),
	Lock: (self: Quest, reason: string?) -> (Quest)
	
}

export type QuestInternal = Quest & {
	_internal: QuestInternal,
	_external: QuestInternal,
	
	_incrementedProgress: number,
			
	_boundMessages: {[Message]: {(...any?) -> ()}},
	_boundSignals: {Signal.Connection},
	
	_updateParent: (self: QuestInternal, parent: Quest?) -> (),

	_handleProgressChange: (self: QuestInternal) -> (),
	_recalculateProgress: (self: QuestInternal) -> (),
	
	_cleanUp: (self: QuestInternal) -> ()
}

return nil

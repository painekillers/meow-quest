--!strict

local Utils = {}

-- Converts a table to read only via creating a proxy
function Utils.readOnly(t, err: string?)
	local proxy = {}
	local mt = {       -- create metatable
		__index = t,
		__newindex = function (t,k,v)
			error(err or "attempt to update a read-only table", 2)
		end
	}
	setmetatable(proxy, mt)
	return proxy
end

-- Shallow copy
function Utils.copy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	
	local copy = {}
	
	for i, v in value :: {[any]: any} do
		copy[i] = v
	end
	
	return copy
end

-- Deep copy including keys and metatables. Supports cyclical tables.
function Utils.deepCopy<T>(value: T, seen: {[any]: any}?): T
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}

	if seen[value] then
		return seen[value]
	end

	local copy = {}
	seen[value] = copy

	for i, v in value :: {[any]: any} do
		copy[Utils.deepCopy(i, seen)] = Utils.deepCopy(v, seen)
	end
	
	local mt = getmetatable(value)
	if mt then
		setmetatable(copy, Utils.deepCopy(mt, seen))
	end 

	return copy
end

return Utils

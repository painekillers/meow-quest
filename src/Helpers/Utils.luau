local Utils = {}

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

return Utils

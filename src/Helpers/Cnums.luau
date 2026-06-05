--!strict

type function generateCnumType(cn: type): type
	const SPEC_LV: number = 1 
	--[[
	0: Base
	1: Shows the Cnum name as "Name" | number 
	2: Shows the Cnum name and possible Cnum values as "Name" | "Value1" | "Value2" ... | number
	]]

	local res = types.newtable(nil, {index = types.string, readresult = types.number, writeresult = types.string})
	
	if cn.tag ~= "table" then
		error(`generateCnumType expects a table type, got '{cn.tag}' type instead.`, 2)
		
		return res
	end
	
	if SPEC_LV == 0 then
		
		return res
	end
	
	for p, rw in cn:properties() do
		local values = {}
		
		if SPEC_LV == 2 and rw.read then
			for val, _ in rw.read:properties() do
				table.insert(values, val)
			end
		end
		
		local indicator = types.unionof(p, types.number, table.unpack(values))
		res:setproperty(p, indicator)
	end
	
	return res
end

local Cnums = {
	
	CompletionState = {
		Unknown = 0,
		Fail = 1,
		Success = 2,
		
	},
	
}

export type Cnums = generateCnumType<typeof(Cnums)>

return Cnums

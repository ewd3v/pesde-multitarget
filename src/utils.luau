local utils = {}

function utils.tableSet(t: {}, path: { any }, value: any)
	local current = t
	for i = 1, #path - 1 do
		local key = path[i]
		if not current[key] then
			current[key] = {}
		end
		current = current[key]
	end
	current[path[#path]] = value
end

return utils

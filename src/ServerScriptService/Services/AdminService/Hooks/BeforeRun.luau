local GROUP_ID = game.CreatorId
local REQUIRED_RANK = 200

local RunContext = require("@Pckgs/RunContext")

local function isAdmin(player)
	if RunContext.IsStudio then
		return true
	end
	return player:GetRankInGroup(GROUP_ID) >= REQUIRED_RANK or player.UserId == game.CreatorId
end

return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		if not isAdmin(context.Executor) then
			return "You don't have permission to run this command"
		end
	end)
end

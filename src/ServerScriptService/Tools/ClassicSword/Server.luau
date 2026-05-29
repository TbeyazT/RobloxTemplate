
local Server = {}

function Server.new(tool,player)
    local self = setmetatable({}, {__index = Server})
    self.Tool = tool
    print(tool)
    return self
end

return Server
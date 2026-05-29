local HttpService = game:GetService("HttpService")

local Server = {}

function Server.new()
    local self = setmetatable({}, {
        __index = Server
    })

    self.ID = HttpService:GenerateGUID()

    print(self.ID)

    return self
end

return Server
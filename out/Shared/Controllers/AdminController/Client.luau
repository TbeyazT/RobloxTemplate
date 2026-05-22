local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage:WaitForChild("CmdrClient",10))

local AdminClient = {}

function AdminClient:Init()
    Cmdr:SetActivationKeys({ Enum.KeyCode.F2 })
end

return AdminClient
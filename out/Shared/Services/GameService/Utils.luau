local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Utils = {}

function Utils:GetWallProperties(name:string)
    local module = Assets.WallProperties:FindFirstChild(name)
    if module and module:IsA("ModuleScript") then
        return require(module)
    end
    return
end

return Utils
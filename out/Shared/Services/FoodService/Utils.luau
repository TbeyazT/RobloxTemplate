local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Utils = {}

function Utils:GetFoodProperties(name:string)
    local module = Assets.FoodProperties:FindFirstChild(name)
    if module and module:IsA("ModuleScript") then
        return require(module)
    end
    return
end

function Utils:GetFoodModel(name:string)
    local module:Instance = Assets.FoodProperties:FindFirstChild(name)
    if module and module:IsA("ModuleScript") then
        return module:FindFirstChildWhichIsA("Model")
    end
    return
end

return Utils
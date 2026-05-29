local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local Utils = {}

function Utils:GetEnemyProperties(enemyName)
    local foundModule = Assets.EnemyProperties:FindFirstChild(enemyName)
    if foundModule and foundModule:IsA("ModuleScript") then
        return require(foundModule)
    else
        warn("Tool properties module not found for tool: " .. enemyName)
        return nil
    end
end

function Utils:GetEnemyModel(enemyName)
    local foundModule = Assets.EnemyProperties:FindFirstChild(enemyName)
    if foundModule and foundModule:IsA("ModuleScript") then
        return foundModule:FindFirstChildWhichIsA("Model")
    else
        warn("Tool properties module not found for tool: " .. enemyName)
        return nil
    end
end

return Utils
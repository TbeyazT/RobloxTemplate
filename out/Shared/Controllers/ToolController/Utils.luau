local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Utils = {}

function Utils:GetToolProperties(toolName)
    local foundModule = Assets.ToolProperties:FindFirstChild(toolName)
    if foundModule and foundModule:IsA("ModuleScript") then
        return require(foundModule)
    else
        warn("Tool properties module not found for tool: " .. toolName)
        return nil
    end
end

function Utils:GetToolModel(toolName)
    local foundModule = Assets.ToolProperties:FindFirstChild(toolName)
    if foundModule and foundModule:IsA("ModuleScript") then
        return foundModule:FindFirstChildWhichIsA("Model")
    else
        warn("Tool properties module not found for tool: " .. toolName)
        return nil
    end
end

return Utils
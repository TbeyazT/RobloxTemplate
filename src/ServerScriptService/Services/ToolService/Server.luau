local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local CharacterService = require("../CharacterService/Server")

local Net = require("../../Constants/Net")
local Utils = require("./Utils")

local ToolService = {
    Classes = {}
}

function ToolService:Init()
    Net.EquipTool.SetCallback(function(Player: Player, Value: string)
        self:EquipTool(Player, Value)
    end)

    Net.UnequipTool.SetCallback(function(Player: Player, Value: string)
        self:UnequipTool(Player, Value)
    end)

    local function playerAdded(player)
        self.Classes[player] = {}
    end

    for _,player in Players:GetPlayers() do
        playerAdded(player)
    end

    Players.PlayerAdded:Connect(playerAdded)
    Players.PlayerRemoving:Connect(function(player)
        for toolName, toolClass in pairs(self.Classes[player]) do
            if toolClass.Destroy then
                toolClass:Destroy()
            end
        end
        self.Classes[player] = nil
    end)
end

function ToolService:EquipTool(Player: Player, ToolName: string)
    local Character = CharacterService:GetCharacter(Player)
    if not Character then return end

    for _, child in ipairs(Character.Model:GetChildren()) do
        if child:GetAttribute("IsTool") then
            self:UnequipTool(Player, child.Name)
        end
    end

    if self.Classes[Player] then
        for existingToolName, _ in pairs(self.Classes[Player]) do
            self:UnequipTool(Player, existingToolName)
        end
    end

    local toolProperties = Utils:GetToolProperties(ToolName)
    if toolProperties then
        local tool = Utils:GetToolModel(ToolName)
        if tool then
            local clonedTool = tool:Clone()
            clonedTool:SetAttribute("IsTool",true)
            clonedTool.Name = ToolName
            local toolScripts = script.Parent.Parent.Parent.Tools:FindFirstChild(ToolName)
            if toolScripts then
                local cloneModule = toolScripts.Client:Clone()
                cloneModule.Parent = clonedTool
                Debris:AddItem(cloneModule, .5)
            end
            clonedTool.Parent = Character.Model
            
            local motor = clonedTool:FindFirstChildWhichIsA("Motor6D")
            if motor then
                motor.Part0 = Character.Model:FindFirstChild("Right Arm")
            end
            
            if self.Classes[Player] then
                local success, serverScript = pcall(function()
                    return require("../../Tools/"..ToolName.."/Server")
                end)
                
                if success and typeof(serverScript) == "table" and typeof(serverScript.new) == "function" then
                    local toolClass = serverScript.new(clonedTool, Player)
                    self.Classes[Player][ToolName] = toolClass
                else
                    if not success then
                        warn("[ToolService] Failed to require server script for tool " .. ToolName .. ":", serverScript)
                    end
                end
            end
        end
    end
end

function ToolService:UnequipTool(Player: Player, ToolName: string)
    local Character = CharacterService:GetCharacter(Player)
    if not Character then return end

    local tool = Character.Model:FindFirstChild(ToolName)
    if tool then
        if self.Classes[Player] and self.Classes[Player][ToolName] then
            local toolClass = self.Classes[Player][ToolName]
            if toolClass.Destroy then
                toolClass:Destroy()
            end
            self.Classes[Player][ToolName] = nil
        end
        tool:Destroy()
    end
end

return ToolService
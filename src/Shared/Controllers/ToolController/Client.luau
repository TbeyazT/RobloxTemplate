--!strict
local Players = game:GetService("Players")

local CharacterController = require("../CharacterController/Client")

local Input = require("@Classes/Player/Input")

local Signal = require("@Pckgs/Signal")

local Net = require("../../Net")
local Utils = require("./Utils")

local ToolController = {
    Classes = {} :: { [Model]: { [string]: any } },
    _charConnections = {} :: { [Model]: { RBXScriptConnection } },
    Activated = Signal.new(),
    Deactivated = Signal.new(),
}

local function characterAdded(player: Player?, char: Model)
    local connections = {}
    
    local function onChildAdded(child: Instance)
        if child:IsA("Model") and Utils:GetToolProperties(child.Name) then
            task.spawn(function()
                local clientModule = child:FindFirstChildWhichIsA("ModuleScript")
                
                if clientModule and clientModule:IsA("ModuleScript") then
                    local success, clientClass = pcall(function()
                        return require(clientModule)::any
                    end)
                    
                    if success and typeof(clientClass) == "table" and typeof(clientClass.new) == "function" then
                        local toolInstance = clientClass.new(child, player)
                        
                        if not ToolController.Classes[char] then
                            ToolController.Classes[char] = {}
                        end
                        ToolController.Classes[char][child.Name] = toolInstance
                        if clientModule then
                            clientModule:Destroy()
                        end
                    else
                        if not success then
                            warn("[ToolController] Failed to require Client module for " .. child.Name .. ":", clientClass)
                        end
                    end
                else
                    warn("[ToolController] Client script was not found or failed to replicate in time for " .. child.Name)
                end
            end)
        end
    end

    local function onChildRemoved(child: Instance)
        if ToolController.Classes[char] and ToolController.Classes[char][child.Name] then
            local toolInstance = ToolController.Classes[char][child.Name]
            if toolInstance and typeof(toolInstance.Destroy) == "function" then
                task.spawn(function()
                    pcall(function()
                        toolInstance:Destroy()
                    end)
                end)
            end
            ToolController.Classes[char][child.Name] = nil
        end
    end

    for _, child in ipairs(char:GetChildren()) do
        onChildAdded(child)
    end

    table.insert(connections, char.ChildAdded:Connect(onChildAdded))
    table.insert(connections, char.ChildRemoved:Connect(onChildRemoved))

    ToolController._charConnections[char] = connections
end

local function characterRemoving(target: any)
    local char: Model? = nil
    if target:IsA("Player") then
        char = target.Character
    elseif target:IsA("Model") then
        char = target
    end

    if char then
        if ToolController._charConnections[char] then
            for _, conn in ipairs(ToolController._charConnections[char]) do
                conn:Disconnect()
            end
            ToolController._charConnections[char] = nil
        end

        if ToolController.Classes[char] then
            for toolName, toolInstance in pairs(ToolController.Classes[char]) do
                if toolInstance and typeof(toolInstance.Destroy) == "function" then
                    pcall(function()
                        toolInstance:Destroy()
                    end)
                end
            end
            ToolController.Classes[char] = nil
        end
    end
end

function ToolController:Init()
    self.Input = Input.new()

    CharacterController.CharacterAdded:Connect(characterAdded)
    CharacterController.CharacterRemoving:Connect(characterRemoving)

    local data = CharacterController:GetPlayerData()
    if data then
        local character = data.Character
        if character then
            characterAdded(Players.LocalPlayer, character)
        end
    end

    self.Input:BindAction("Activation", function(actionName: string, state: Enum.UserInputState, input: InputObject, gameProcessed: boolean)
        if gameProcessed then return end
        if state == Enum.UserInputState.Begin then
            self.Activated:Fire()
        elseif state == Enum.UserInputState.End then
            self.Deactivated:Fire()
        end
    end, {
        Enum.UserInputType.MouseButton1,
        Enum.UserInputType.Touch,
    })
end

function ToolController:EquipTool(toolName: string)
    Net.EquipTool.Fire(toolName)
end

function ToolController:UnequipTool(toolName: string)
    if Net.UnequipTool then
        Net.UnequipTool.Fire(toolName)
    else
        warn("[ToolController] Net.UnequipTool is not registered in Net constants.")
    end
end

return ToolController
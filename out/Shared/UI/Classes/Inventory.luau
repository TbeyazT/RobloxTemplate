local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local RunContext = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('RunContext'))
local Trove = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))
local React = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('React'))

local Button = require(script.Parent.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('UI'):FindFirstChild('Button'))

local CharacterController = require(script.Parent.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('CharacterController'):FindFirstChild('Client'))
local ToolController = require(script.Parent.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('ToolController'):FindFirstChild('Client'))
local ToolUtils = require(script.Parent.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('ToolController'):FindFirstChild('Utils'))

if RunContext.IsEdit then
    CharacterController:Init()
end

local Inventory = {
    Order = 11,
}

local numberWords = {
    [1] = "One",
    [2] = "Two",
    [3] = "Three",
    [4] = "Four",
    [5] = "Five",
    [6] = "Six",
    [7] = "Seven",
    [8] = "Eight",
    [9] = "Nine",
    [10] = "Ten"
}

local function ToolTemplate(properties)
    local newFont = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
    local viewportRef = React.useRef(nil :: ViewportFrame?)
    local toolProperties = ToolUtils:GetToolProperties(properties.Name)

    React.useEffect(function()
        local viewport = viewportRef.current
        if not viewport then return end

        local toolModel = toolProperties and ToolUtils:GetToolModel(properties.Name)
        if toolModel then
            local modelClone = toolModel:Clone()
            modelClone.Parent = viewport.WorldModel
            modelClone:PivotTo(CFrame.new(0, 0, 0))
            
            local camera = Instance.new("Camera")
            camera.Parent = viewport
            viewport.CurrentCamera = camera
            camera.CFrame = toolProperties.Viewport.CameraCFrame

            return function()
                modelClone:Destroy()
                camera:Destroy()
            end
        end
        return function() end
    end, { properties.Name })

    return React.createElement(Button, {
        Name = properties.Name,
        Size = UDim2.fromScale(0.114, 0.8),
        BackgroundTransparency = 0.2,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        LayoutOrder = properties.Index,
        OnClick = function()
            if properties.Equipped then
                ToolController:UnequipTool(properties.Name)
            else
                ToolController:EquipTool(properties.Name)
            end
        end,
        KeyCode = Enum.KeyCode[numberWords[properties.Index] ],
    }, {
        UIGradient = React.createElement("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(35,35,35)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(95,95,95)),
            }),
            Rotation = 85,
        }),
        UIStroke = React.createElement("UIStroke",{
            Color = Color3.fromRGB(255,255,255),
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            BorderStrokePosition = Enum.BorderStrokePosition.Outer,
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            LineJoinMode = Enum.LineJoinMode.Miter,
            Thickness = 0.02,
            Transparency = 0.58,
        }),
        TextLabel = React.createElement("TextLabel",{
            Size = UDim2.fromScale(0.22,0.22),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            FontFace = newFont,
            Text = tostring(properties.Index),
            TextScaled = true,
        },{
            UIStroke = React.createElement("UIStroke",{
                Color = Color3.fromRGB(0, 0, 0),
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                LineJoinMode = Enum.LineJoinMode.Miter,
                Thickness = 0.06,
            })
        }),
        ImageLabel = React.createElement("ImageLabel",{
            Size = UDim2.fromScale(1,1),
            Position = UDim2.fromScale(0.5,0.5),
            AnchorPoint = Vector2.new(0.5,0.5),
            BackgroundTransparency = 1,
            ImageColor3 = Color3.fromRGB(83,83,83),
            ImageTransparency = 0.27,
            Image = "rbxassetid://108616549109971",
            ZIndex = 0,
        }),
        ViewportFrame = React.createElement("ViewportFrame",{
            ref = viewportRef,
            Size = UDim2.fromScale(0.9,0.9),
            Position = UDim2.fromScale(0.5,0.5),
            AnchorPoint = Vector2.new(0.5,0.5),
            BackgroundTransparency = 1,
            ZIndex = 1,
        },{
            WorldModel = React.createElement("WorldModel", {
                Name = "WorldModel",
            })
        }),
        EquippedStroke = React.createElement("UIStroke",{
            Color = Color3.fromRGB(255,255,255),
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            BorderStrokePosition = Enum.BorderStrokePosition.Outer,
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            LineJoinMode = Enum.LineJoinMode.Round,
            Thickness = 0.035,
            Transparency = properties.Equipped and 0 or 1,
        }),
    })
end

local function App()
    local initialTools = {}
    local tools, setTools = React.useState(initialTools)

    React.useEffect(function()
        local cleanTrove = Trove.new()
        local toolPropertiesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ToolProperties")
        
        local toolSlots = {} 
        local occupiedSlots = {}

        local function updateTools()
            local ownedTools = {}
            local equippedTools = {}

            local characterData = CharacterController:GetPlayerData()
            if characterData and characterData.Inventory then
                ownedTools = characterData.Inventory
            else
                for _, child in ipairs(toolPropertiesFolder:GetChildren()) do
                    if child:IsA("ModuleScript") then
                        table.insert(ownedTools, child.Name)
                    end
                end
            end

            local character = LocalPlayer.Character
            if character then
                for _, toolName in ipairs(ownedTools) do
                    if character:FindFirstChild(toolName) then
                        equippedTools[toolName] = true
                    end
                end
            end

            local activeLookup = {}
            for _, toolName in ipairs(ownedTools) do
                activeLookup[toolName] = true
            end

            for toolName, slot in pairs(toolSlots) do
                if not activeLookup[toolName] then
                    toolSlots[toolName] = nil
                    occupiedSlots[slot] = nil
                end
            end

            local startSlot = RunContext.IsEdit and 2 or 1
            for _, toolName in ipairs(ownedTools) do
                if not toolSlots[toolName] then
                    local assignedSlot = nil
                    for i = startSlot, 10 do
                        if not occupiedSlots[i] then
                            assignedSlot = i
                            break
                        end
                    end
                    
                    if assignedSlot then
                        toolSlots[toolName] = assignedSlot
                        occupiedSlots[assignedSlot] = true
                    end
                end
            end

            local updatedList = {}
            if RunContext.IsEdit then
                table.insert(updatedList, {
                    Name = "ClassicSword",
                    Index = 1,
                    Tool = nil,
                    Equipped = false,
                })
            end

            for toolName, slot in pairs(toolSlots) do
                table.insert(updatedList, {
                    Name = toolName,
                    Index = slot,
                    Tool = toolName,
                    Equipped = not not equippedTools[toolName],
                })
            end

            table.sort(updatedList, function(a, b)
                return a.Index < b.Index
            end)

            setTools(updatedList)
        end

        local characterTrove = cleanTrove:Extend()
        local function onCharacterAdded(char)
            characterTrove:Clean()
            characterTrove:Connect(char.ChildAdded, updateTools)
            characterTrove:Connect(char.ChildRemoved, updateTools)
            updateTools()
        end

        if LocalPlayer.Character then
            onCharacterAdded(LocalPlayer.Character)
        end
        cleanTrove:Connect(LocalPlayer.CharacterAdded, onCharacterAdded)

        updateTools()

        return function()
           cleanTrove:Destroy()
        end
    end, {})

    local children = {
        UIListLayout = React.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0.02, 0),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }

    for _, toolData in ipairs(tools) do
        if typeof(toolData) == "table" then
            children[toolData.Name .. "_" .. toolData.Index] = React.createElement(ToolTemplate, toolData)
        end
    end

    return React.createElement("Frame",{
        Name = "HotbarFrame",
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromScale(0.464, 0.124),
        Position = UDim2.fromScale(0.5, 1),
        BackgroundTransparency = 1,
    }, {
        UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {
            AspectRatio = 6.5,
            AspectType = Enum.AspectType.FitWithinMaxSize,
            DominantAxis = Enum.DominantAxis.Width,
        }),
        Frame = React.createElement("Frame",{
            Size = UDim2.fromScale(1,1),
            AnchorPoint = Vector2.new(0.5,0.5),
            Position = UDim2.fromScale(0.5,0.5),
            BackgroundTransparency = 1,
        }, children)
    })
end

function Inventory:Init()
    local success, err = pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    end)

    if not success then
        task.spawn(function()
            while task.wait() do
                local successRetry, errRetry = pcall(function()
                    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
                end)
                if successRetry then
                    break
                end
            end
        end)
    end

    print("[Inventory] Module initialization completed.")
end

function Inventory:Render()
    return React.createElement(App)
end

function Inventory:Destroy()
    print("[Inventory] Module clean-up completed.")
end

return Inventory
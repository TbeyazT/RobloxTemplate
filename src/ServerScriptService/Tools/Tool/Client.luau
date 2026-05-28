
local CharacterController = require("@Shared/Controllers/CharacterController/Client")
local ToolController = require("@Shared/Controllers/ToolController/Client")

local GetHumanoid = require("@Modules/Core/Animation/GetAnimator")

local Input = require("@Classes/Player/Input")

local Shapecast = require("@Pckgs/ShapecastHitbox")
local Trove = require("@Pckgs/Trove")

local Client = {}

function Client.new(tool,player)
    local self = setmetatable({}, {__index = Client})

    Shapecast.Settings.Debug_Visible = true

    self.Player = player
    self.Tool = tool

    self.CleanTrove = Trove.new()
    self:InitHitbox()

    ToolController.Activated:Connect(function(...)
        self.Hitbox:HitStart(1)
    end)

    ToolController.Deactivated:Connect(function(...)
        print("noyo")
    end)

    return self
end

function Client:InitHitbox()
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {self.Tool}

    local data = CharacterController:GetPlayerData()
    if data and data.Character then
        rayParams:AddToFilter(data.Character)
    end

    self.Hitbox = Shapecast.new(self.Tool,rayParams)

    self.Hitbox:OnHit(function(rayResult:RaycastResult)
        local hitPart = rayResult.Instance
        if hitPart and hitPart.Parent then
            local humanoid = GetHumanoid(hitPart.Parent)
            if humanoid then
                print("hit")
            end
        end
    end)
end

function Client:Destroy()
    self.CleanTrove:Destroy()
end

return Client
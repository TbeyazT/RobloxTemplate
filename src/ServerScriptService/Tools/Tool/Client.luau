local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local CharacterController = require("@Shared/Controllers/CharacterController/Client")
local ToolController = require("@Shared/Controllers/ToolController/Client")

local GetHumanoid = require("@Modules/Core/Animation/GetAnimator")

local Tween = require("@Classes/Animation/Tween")
local Input = require("@Classes/Player/Input")

local Bezier = require("@Modules/Math/Bezier")
local Easing = require("@Modules/Math/Easing")

local Shapecast = require("@Pckgs/ShapecastHitbox")
local Trove = require("@Pckgs/Trove")

local Segments = 2

local Client = {}

function Client.new(tool,player)
    local self = setmetatable({}, {__index = Client})

    Shapecast.Settings.Debug_Visible = true

    self.Player = player
    self.Tool = tool

    self.CleanTrove = Trove.new()
    self.Input = Input.new()

    ToolController.Activated:Connect(function(...)
        self:Fire()    
    end)

    ToolController.Deactivated:Connect(function(...)
        print("noyo")
    end)

    return self
end

function Client:Fire()
    local Segments = 2 
    local BulletSpeed = 150

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {self.Tool,workspace.Debris:GetChildren()}

    local data = CharacterController:GetPlayerData()
    if data and data.Character then
        rayParams:AddToFilter(data.Character)
    end

    local mouseRayResult = self.Input:GetMouseWorldRay(rayParams.FilterDescendantsInstances)

    if mouseRayResult then
        local firePoint = self.Tool.Handle:FindFirstChild("FirePoint") or self.Tool.Handle
        local startPos = firePoint.WorldPosition
        local endPos = mouseRayResult.Position

        local totalDistance = (endPos - startPos).Magnitude
        local segmentLength = totalDistance / Segments
        local direction = (endPos - startPos).Unit

        local upVector = Vector3.new(0, 1, 0)
        local rightVector = direction:Cross(upVector)
        if rightVector.Magnitude < 0.001 then
            rightVector = Vector3.new(1, 0, 0)
        else
            rightVector = rightVector.Unit
        end
        upVector = rightVector:Cross(direction).Unit

        local minOffset = 3
        local maxOffset = 6
        local randomRight = (math.random() > 0.5 and 1 or -1) * math.random(minOffset, maxOffset)
        local randomUp = (math.random() > 0.5 and 1 or -1) * math.random(minOffset, maxOffset)
        local baseOffset = (rightVector * randomRight) + (upVector * randomUp)

        local bullet = Assets.Models.Bullet:Clone()
        bullet.Position = startPos
        bullet.Parent = workspace.Debris

        task.spawn(function()
            local currentStart = startPos

            for i = 1, Segments do
                local p0 = currentStart
                local p2 = startPos + (direction * (segmentLength * i))

                local multiplier = if i % 2 == 1 then 1 else -1
                local curveOffset = baseOffset * multiplier

                local pMid = Bezier.lerp(p0, p2, 0.5) + curveOffset

                local p1 = (pMid * 2) - ((p0 + p2) * 0.5)

                local segmentDistance = (p2 - p0).Magnitude
                local duration = segmentDistance / BulletSpeed
                local elapsed = 0

                while elapsed < duration do
                    local dt = task.wait()
                    elapsed = math.min(elapsed + dt, duration)
                    local t = elapsed / duration

                    local currentPos = Bezier.Quadratic(p0, p1, p2, t)
                    local nextPos = Bezier.Quadratic(p0, p1, p2, math.min(t + 0.05, 1))
                    
                    if (nextPos - currentPos).Magnitude > 0.001 then
                        bullet.CFrame = CFrame.lookAt(currentPos, nextPos)
                    else
                        bullet.Position = currentPos
                    end
                end

                currentStart = p2
            end

            bullet:Destroy()
        end)
    end
end

function Client:Destroy()
    self.CleanTrove:Destroy()
end

return Client
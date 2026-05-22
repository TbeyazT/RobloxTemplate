local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Assets = ReplicatedStorage:FindFirstChild("Assets")

local Framework = require(script.Parent.Parent.Parent:FindFirstChild('Framework'))
local Net = require(script.Parent.Parent.Parent:FindFirstChild('Net'))

local PlotClass = require(script.Parent.PlotClass)
local LocalPlayer = Players.LocalPlayer

local PlotController = {}

function PlotController:Init()
    self.ProfileService = Framework.Get("ProfileService")
    self.MyPlotCFrame = nil
    self.MyPlotFolder = nil
    
    self.AllClientPlots = {} 
end

function PlotController:Start()
    local plotsFolder = workspace:WaitForChild("Plots")

    Net.PlotAssigned.On(function(data)
        local userId = data.UserId
        local cframe = data.PlotCFrame
        local userIdStr = tostring(userId)

        local player = Players:GetPlayerByUserId(userId)

        if not player then
            warn("Received plot data for non-existent player with UserId: " .. userId)
            return
        end
        
        if self.AllClientPlots[userIdStr] then return end

        local newFolder = Instance.new("Folder")
        newFolder.Name = userIdStr .. "_Plot"
        
        local brainrotPlots = Instance.new("Folder")
        brainrotPlots.Name = "Plots"
        brainrotPlots.Parent = newFolder
        
        local clonePlot = Assets.Models.Base:Clone()
        clonePlot.Name = "PlotBase"
        clonePlot:PivotTo(cframe)
        clonePlot.Parent = newFolder
        
        newFolder.Parent = plotsFolder

        local partBillboard = clonePlot:FindFirstChild("PlayerBillboard", true)
        if partBillboard then
            local pFrame = partBillboard:FindFirstChildWhichIsA("Frame", true)
            if pFrame then
                local pName = pFrame:FindFirstChild("PlayerName")
                local pIcon = pFrame:FindFirstChild("PlayerIcon")

                if pName then pName.Text = "@" .. player.Name end
                if pIcon then 
                    pIcon.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size352x352) 
                end
            end
        end

        local plotData = PlotClass.new({
            Owner = player,
            PlotFolder = newFolder, 
            PlotBase = clonePlot,  
            BrainrotPlots = brainrotPlots
        })

        self.AllClientPlots[userIdStr] = {
            Folder = newFolder,
            PlotClass = plotData,
        }

        if userId == LocalPlayer.UserId then
            self.MyPlotCFrame = cframe
            self.MyPlotFolder = newFolder
        end
        
        plotData:UpdatePlot()
    end)

    Net.PlotRemoved.On(function(data)
        local userId = data.UserId
        local userIdStr = tostring(userId)
        local plotData = self.AllClientPlots[userIdStr]
        
        if plotData then
            if typeof(plotData.PlotClass.Destroy) == "function" then
                plotData.PlotClass:Destroy()
            end
            
            if plotData.Folder then
                plotData.Folder:Destroy()
            end
            
            self.AllClientPlots[userIdStr] = nil
        end

        if userId == LocalPlayer.UserId then
            self.MyPlotCFrame = nil
            self.MyPlotFolder = nil
        end
    end)
end

function PlotController:GetMyPlotFolder(): Folder?
    return self.MyPlotFolder
end

function PlotController:GetPlotClass(player: Player)
    local userIdStr = tostring(player.UserId)
    local plotData = self.AllClientPlots[userIdStr]
    return plotData and plotData.PlotClass or nil
end

return PlotController
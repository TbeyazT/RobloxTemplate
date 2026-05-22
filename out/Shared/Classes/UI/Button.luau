local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = ReplicatedStorage:WaitForChild("Assets")

local Trove = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('Trove'))

local Button = {}

_G.ActiveFrame = "CH12"

function Button.new(UI,Data)
	local self = setmetatable({}, {
		__index = Button
	})

	self.UI = UI
	self.Enabled = true
	self.CanAnimate = true
	self.SfxEnabled = true
	self.OriSize = self.UI.Size

	self.UpScale = 1.1
	self.DownScale = 0.8
	self.OnHover = nil
	self.OnUnHover = nil
	self.OnMouseDown = nil
	self.OnMouseUp = nil
	
	self.IsDown = false 

	self.TI = Data and Data.TweenInfo or TweenInfo.new(0.3, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

	self.HoverTween = TweenService:Create(UI, self.TI, {
		Size = UDim2.fromScale(self.UI.Size.X.Scale * self.UpScale, self.UI.Size.Y.Scale * self.UpScale)
	})

	self.HoverLeaveTween = TweenService:Create(UI, self.TI, {
		Size = UDim2.fromScale(self.OriSize.X.Scale, self.OriSize.Y.Scale)
	})

	self.MouseDownTween = TweenService:Create(UI, self.TI, {
		Size = UDim2.fromScale(self.UI.Size.X.Scale * self.DownScale, self.UI.Size.Y.Scale * self.DownScale)
	})

	self.MouseUpTween = TweenService:Create(UI, self.TI, {
		Size = UDim2.fromScale(self.OriSize.X.Scale, self.OriSize.Y.Scale)
	})

	self.Connections = Trove.new()

	self.UI.Destroying:Connect(function()
		if self.destroy then
			self:destroy()
		end
	end)

	return self
end

function Button:Enable()
	self.Enabled = true
end

function Button:Disable()
	self.Enabled = false
	self.IsDown = false
end

function Button:UpdateTweens()
	self.HoverTween = TweenService:Create(self.UI, self.TI, {
		Size = UDim2.fromScale(self.UI.Size.X.Scale * self.UpScale, self.UI.Size.Y.Scale * self.UpScale)
	})
	self.HoverLeaveTween = TweenService:Create(self.UI, self.TI, {
		Size = UDim2.fromScale(self.OriSize.X.Scale, self.OriSize.Y.Scale)
	})
	self.MouseDownTween = TweenService:Create(self.UI, self.TI, {
		Size = UDim2.fromScale(self.UI.Size.X.Scale * self.DownScale, self.UI.Size.Y.Scale * self.DownScale)
	})
	self.MouseUpTween = TweenService:Create(self.UI, self.TI, {
		Size = UDim2.fromScale(self.OriSize.X.Scale, self.OriSize.Y.Scale)
	})
end

function Button:Hover()
	if self.CanAnimate then
		self.HoverTween:Play()
	end
	local hoverSound = Assets.Sounds.UI:FindFirstChild("Hover")
	if hoverSound then
		if self.SfxEnabled then
			hoverSound:Play()
		end
	end
	if self.OnHover then
		self.OnHover(self.UI)
	end
end

function Button:UnHover()
	if self.CanAnimate then
		self.HoverLeaveTween:Play()
	end
	if self.OnUnHover then
		self.OnUnHover(self.UI)
	end
end

function Button:MouseDown()
	if self.CanAnimate then
		self.MouseDownTween:Play()
	end
	if self.OnMouseDown then
		self.OnMouseDown(self.UI)
	end
end

function Button:MouseUp()
	if self.CanAnimate then
		self.MouseUpTween:Play()
	end
	local clickSound = Assets.Sounds.UI:FindFirstChild("Click")
	if clickSound and self.SfxEnabled then
		clickSound:Play()
	end
	if self.OnMouseUp then
		self.OnMouseUp(self.UI)
	end
end

function Button:Init(func,KeyCode:Enum.KeyCode)
	self.Connections:Clean()
	
	self.IsDown = false

	self.Connections:Connect(self.UI.MouseEnter, function()
        if not self.Enabled then return end
        self:Hover()
    end)

	self.Connections:Connect(self.UI.MouseLeave, function()
        if not self.Enabled then return end
		self.IsDown = false 
		self:UnHover()
    end)

	if self.UI:IsA("GuiButton") then
		self.Connections:Connect(self.UI.MouseButton1Down, function()
            if not self.Enabled then return end
			self.IsDown = true 
			self:MouseDown()
        end)

		self.Connections:Connect(self.UI.MouseButton1Up, function()
            if not self.Enabled then return end
			
			if self.IsDown then
				self:MouseUp()
				if func and type(func) == "function" then
					func()
				end
			end
			
			self.IsDown = false
        end)
	end

	if KeyCode then
		self.Connections:Connect(UserInputService.InputBegan, function(input, gpe)
			if gpe or not self.Enabled then return end
			if input.KeyCode == KeyCode then
				self:MouseDown()
			end
		end)

		self.Connections:Connect(UserInputService.InputEnded, function(input, gpe)
			if gpe or not self.Enabled then return end
			if input.KeyCode == KeyCode then
				self:MouseUp()
				if func and type(func) == "function" then
					func()
				end
			end
		end)
	end
end

function Button:Destroy()
	self.Connections:Destroy()

	if self.HoverTween then
		self.HoverTween:Cancel()
		self.HoverTween:Destroy()
		self.HoverTween = nil
	end

	if self.HoverLeaveTween then
		self.HoverLeaveTween:Cancel()
		self.HoverLeaveTween:Destroy()
		self.HoverLeaveTween = nil
	end

	if self.MouseDownTween then
		self.MouseDownTween:Cancel()
		self.MouseDownTween:Destroy()
		self.MouseDownTween = nil
	end

	if self.MouseUpTween then
		self.MouseUpTween:Cancel()
		self.MouseUpTween:Destroy()
		self.MouseUpTween = nil
	end

	self.UI.Size = self.OriSize

	setmetatable(self,nil)
end

return Button
--[[
	// FileName: SpriteSheetComponent.lua
	// Description: Animates a sprite sheet using ImageRect properties.
	@TbeyazT 2025
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(Packages.Signal)

local SpriteSheetComponent = {}
SpriteSheetComponent.__index = SpriteSheetComponent

--// Types
export type SpriteConfig = {
	SpriteSize: Vector2,   -- The size of a single frame (e.g., Vector2.new(64, 64))
	Frames: number,        -- Total number of frames in the animation
	FPS: number?,          -- Frames per second (default 30)
	Loop: boolean?,        -- Should it loop? (default true)
	Columns: number?,      -- How many sprites per row
}

export type SpriteSheetComponent = {
	ImageLabel: ImageLabel,
	Config: SpriteConfig,
	CurrentFrame: number,
	IsPlaying: boolean,
	OnLoop: any,
	OnFinished: any,
	Play: (SpriteSheetComponent) -> (),
	Pause: (SpriteSheetComponent) -> (),
	Stop: (SpriteSheetComponent) -> (),
	SetFrame: (SpriteSheetComponent, number) -> (),
	Destroy: (SpriteSheetComponent) -> (),
}

function SpriteSheetComponent.new(label: ImageLabel, config: SpriteConfig)
	local self = setmetatable({}, SpriteSheetComponent)

	self.ImageLabel = label
	self.Config = config
	self.Config.FPS = config.FPS or 30
	self.Config.Loop = (config.Loop == nil) and true or config.Loop

	self.CurrentFrame = 1
	self.IsPlaying = false
	self._Elapsed = 0

	self.OnLoop = Signal.new()
	self.OnFinished = Signal.new()

	label.ImageRectSize = config.SpriteSize

	local function updateColumns()
		if config.Columns then
			self.Config.Columns = config.Columns
		else
			self.Config.Columns = config.Frames
		end
		self:SetFrame(self.CurrentFrame)
	end

	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateColumns)
	updateColumns()

	self._Connection = RunService.Heartbeat:Connect(function(dt)
		self:_Update(dt)
	end)

	return self
end

function SpriteSheetComponent:_Update(dt: number)
	if not self.IsPlaying then return end

	self._Elapsed += dt
	local frameDuration = 1 / self.Config.FPS

	if self._Elapsed >= frameDuration then
		self._Elapsed = 0
		local nextFrame = self.CurrentFrame + 1

		if nextFrame > self.Config.Frames then
			if self.Config.Loop then
				nextFrame = 1
				self.OnLoop:Fire()
			else
				nextFrame = self.Config.Frames
				self:Pause()
				self.OnFinished:Fire()
				return
			end
		end

		self:SetFrame(nextFrame)
	end
end

function SpriteSheetComponent:SetFrame(frameIndex: number)
	if not self.Config.Columns or self.Config.Columns <= 0 then return end

	self.CurrentFrame = math.clamp(frameIndex, 1, self.Config.Frames)

	local cols = self.Config.Columns
	local spriteSize = self.Config.SpriteSize

	local zeroIndex = self.CurrentFrame - 1
	local xIdx = zeroIndex % cols
	local yIdx = math.floor(zeroIndex / cols)

	self.ImageLabel.ImageRectOffset = Vector2.new(
		xIdx * spriteSize.X,
		yIdx * spriteSize.Y
	)
end

function SpriteSheetComponent:Play()
	self.IsPlaying = true
end

function SpriteSheetComponent:Pause()
	self.IsPlaying = false
end

function SpriteSheetComponent:Stop()
	self.IsPlaying = false
	self:SetFrame(1)
end

function SpriteSheetComponent:Destroy()
	if self._Connection then
		self._Connection:Disconnect()
		self._Connection = nil
	end
	self.OnLoop:Destroy()
	self.OnFinished:Destroy()
	self = nil
end

return SpriteSheetComponent
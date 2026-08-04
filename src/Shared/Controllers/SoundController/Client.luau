const Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local Assets = ReplicatedStorage:WaitForChild("Assets")

const ProfileController = require("@Controllers/ProfileController/Client")

const RunContext = require("@Pckgs/RunContext")

local Framework = require("@Shared/Framework")
local Net = require("@Shared/Net")

local Audios = Assets:WaitForChild("Sounds")

local SoundController = {	
	_activeLoops = {},
	_musicTracks = {},
	_currentMusicIndex = 1,
	_currentMusicSound = nil :: Sound?,
	_musicEnabled = true,
	_musicIcon = nil :: any,
}

function SoundController:init()
end

function SoundController:Start()
	Net.PlayAudio.SetCallback(function(Value)
        self:PlaySound(Value.SoundName, Value.Properties)
    end)

	self:_InitBackgroundMusic()
	self:_InitTopBarIcon()
end

function SoundController:_InitBackgroundMusic()
	local musicFolder = Audios:FindFirstChild("BackgroundMusics", true) or Assets:FindFirstChild("BackgroundMusics", true)
	if not musicFolder then
		warn("[SoundController] BackgroundMusics folder not found in Assets!")
		return 
	end

	local tracks = {}
	for _, child in ipairs(musicFolder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(tracks, child)
		end
	end

	if #tracks == 0 then 
		warn("[SoundController] No Sound instances found in BackgroundMusics!")
		return 
	end

	self._musicTracks = tracks
	self._currentMusicIndex = 1

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(tracks)
		end)
	end)

	local function playTrack(index: number)
		if self._currentMusicSound then
			self._currentMusicSound:Destroy()
			self._currentMusicSound = nil
		end

		local trackTemplate = self._musicTracks[index]
		if not trackTemplate then return end

		local sound = trackTemplate:Clone()
		sound.Looped = false
		if sound.Volume <= 0 then sound.Volume = 0.5 end
		sound.Parent = SoundService
		self._currentMusicSound = sound

		if self._musicEnabled then
			sound:Play()
		end

		sound.Ended:Connect(function()
			if sound.TimeLength > 0 then
				if self._musicTracks and #self._musicTracks > 0 then
					self._currentMusicIndex = (self._currentMusicIndex % #self._musicTracks) + 1
					playTrack(self._currentMusicIndex)
				end
			else
				task.wait(2)
				if self._musicTracks and #self._musicTracks > 0 then
					self._currentMusicIndex = (self._currentMusicIndex % #self._musicTracks) + 1
					playTrack(self._currentMusicIndex)
				end
			end
		end)
	end

	playTrack(self._currentMusicIndex)

	ProfileController:Observe("Settings", function(settings)
		local isEnabled = true
		if settings and settings.Music ~= nil then
			isEnabled = (settings.Music == true)
		end
		self:SetMusicEnabled(isEnabled)
	end)
end

function SoundController:_InitTopBarIcon()
	const Icon = require("@Pckgs/Icon")
	const musicIcon = Icon.new()
	musicIcon:setImage("rbxassetid://10734950309")
	musicIcon:setCaption("Toggle Music")

	local isUpdatingFromProfile = false

	musicIcon:bindEvent("selected", function()
		musicIcon:setImage("rbxassetid://84690920899968")
		if isUpdatingFromProfile then return end
		Net.ChangeSetting.Call("Music")
	end)

	musicIcon:bindEvent("deselected", function()
		musicIcon:setImage("rbxassetid://123632149036764")
		if isUpdatingFromProfile then return end
		Net.ChangeSetting.Call("Music")
	end)

	self._musicIcon = musicIcon

	ProfileController:Observe("Settings", function(settings)
		local isEnabled = true
		if settings and settings.Music ~= nil then
			isEnabled = (settings.Music == true)
		end

		isUpdatingFromProfile = true
		if isEnabled then
			musicIcon:select()
		else
			musicIcon:deselect()
		end
		isUpdatingFromProfile = false
	end)
end

function SoundController:SetMusicEnabled(enabled: boolean)
	self._musicEnabled = enabled

	if self._currentMusicSound then
		if enabled then
			if not self._currentMusicSound.IsPlaying then
				self._currentMusicSound:Play()
			end
		else
			if self._currentMusicSound.IsPlaying then
				self._currentMusicSound:Pause()
			end
		end
	end
end

function SoundController:PlaySound(soundName, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end

	local sound: Sound = soundTemplate:Clone()
	if properties then 
		self:_ApplyProperties(sound, properties) 
	end

	if sound.Volume <= 0 then 
		sound.Volume = soundTemplate.Volume > 0 and soundTemplate.Volume or 0.5 
	end

	sound.Parent = SoundService

	sound.Ended:Once(function()
		sound:Destroy()
	end)

	task.delay(15, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)

	SoundService:PlayLocalSound(sound)
	return sound
end

function SoundController:PlaySound3D(soundName, target, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end

	local sound: Sound = soundTemplate:Clone()
	if properties then self:_ApplyProperties(sound, properties) end

	local attachment = nil
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		sound.Parent = target
	elseif typeof(target) == "Vector3" then
		attachment = Instance.new("Attachment")
		attachment.WorldPosition = target
		attachment.Parent = Workspace.Terrain
		sound.Parent = attachment
	else
		warn("[SoundController] Invalid target for 3D sound", target)
		return
	end

	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
		if attachment then attachment:Destroy() end
	end)

	return sound
end

function SoundController:StartLoop(soundName, properties)
	local soundTemplate = self:_GetSound(soundName)
	if not soundTemplate then return end

	local id = game:GetService("HttpService"):GenerateGUID(false)
	local sound: Sound = soundTemplate:Clone()
	if properties then self:_ApplyProperties(sound, properties) end
	if sound.Volume <= 0 then sound.Volume = soundTemplate.Volume > 0 and soundTemplate.Volume or 0.5 end

	sound.Looped = true
	sound.Parent = SoundService
	sound:Play()
	self._activeLoops[id] = sound
	return id
end

function SoundController:StopLoop(loopId, fadeTime)
	local sound = self._activeLoops[loopId]
	if sound then
		self._activeLoops[loopId] = nil
		if fadeTime then
			local tween = TweenService:Create(sound, TweenInfo.new(fadeTime), { Volume = 0 })
			tween:Play()
			tween.Completed:Connect(function() sound:Destroy() end)
		else
			sound:Destroy()
		end
	end
end

function SoundController:PlayRandom(soundName, properties, Position)
	properties = properties or {}
	local basePitch = properties.Pitch or 1
	local variance = 0.1
	properties.Pitch = basePitch + (math.random() * variance * 2 - variance)

	if Position then
		return self:PlaySound3D(soundName, Position, properties)
	else
		return self:PlaySound(soundName, properties)
	end
end

function SoundController:_GetSound(name)
	local sound = Audios:FindFirstChild(name, true)
	if not sound then 
		warn("[SoundController] Sound not found:", tostring(name))
		return nil 
	end
	return sound
end

function SoundController:_ApplyProperties(soundInstance, props)
	if props then 
		for k, v in pairs(props) do 
			soundInstance[k] = v 
		end 
	end
end

return SoundController
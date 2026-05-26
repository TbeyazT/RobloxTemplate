--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local React = require("@Pckgs/React")

local Assets = ReplicatedStorage:WaitForChild("Assets")

type Props = {
	Enabled: boolean?,
	SfxEnabled: boolean?,
	UpScale: number?,
	DownScale: number?,
	TweenInfo: TweenInfo?,
	KeyCode: Enum.KeyCode?,
	OnClick: (() -> ())?,
	
	Size: UDim2?,
	[string]: any
}

local function Button(props: Props)
	local enabled = if props.Enabled ~= nil then props.Enabled else true
	local sfxEnabled = if props.SfxEnabled ~= nil then props.SfxEnabled else true
	local upScale = props.UpScale or 1.1
	local downScale = props.DownScale or 0.8
	local baseSize = props.Size or UDim2.fromScale(1, 1)
	
	local tweenInfo = props.TweenInfo or TweenInfo.new(
		0.3, 
		Enum.EasingStyle.Circular, 
		Enum.EasingDirection.Out
	)

	local buttonRef = React.useRef(nil :: GuiButton?)
	local currentTweenRef = React.useRef(nil :: Tween?)
	local isDownRef = React.useRef(false)

	local function getScaledSize(size: UDim2, multiplier: number): UDim2
		return UDim2.new(
			size.X.Scale * multiplier,
			size.X.Offset * multiplier,
			size.Y.Scale * multiplier,
			size.Y.Offset * multiplier
		)
	end

	local function playTween(targetSize: UDim2)
		local button = buttonRef.current
		if not button then return end

		if currentTweenRef.current then
			currentTweenRef.current:Cancel()
			currentTweenRef.current:Destroy()
		end

		local tween = TweenService:Create(button, tweenInfo, { Size = targetSize })
		currentTweenRef.current = tween
		tween:Play()
	end

	local function playSound(soundName: string)
		if not sfxEnabled then return end
		local sound = Assets.Sounds.UI:FindFirstChild(soundName)
		if sound then
			sound:Play()
		end
	end

	local function onMouseEnter()
		if not enabled then return end
		playTween(getScaledSize(baseSize, upScale))
		playSound("Hover")
	end

	local function onMouseLeave()
		if not enabled then return end
		isDownRef.current = false
		playTween(baseSize)
	end

	local function onMouseButton1Down()
		if not enabled then return end
		isDownRef.current = true
		playTween(getScaledSize(baseSize, downScale))
	end

	local function onMouseButton1Up()
		if not enabled then return end
		if isDownRef.current then
			playTween(baseSize)
			playSound("Click")
			if props.OnClick then
				props.OnClick()
			end
		end
		isDownRef.current = false
	end

	React.useEffect(function()
		if not props.KeyCode or not enabled then return end

		local inputBeganConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == props.KeyCode then
				isDownRef.current = true
				playTween(getScaledSize(baseSize, downScale))
			end
		end)

		local inputEndedConn = UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.KeyCode == props.KeyCode then
				playTween(baseSize)
				playSound("Click")
				if props.OnClick then
					props.OnClick()
				end
				isDownRef.current = false
			end
		end)

		return function()
			inputBeganConn:Disconnect()
			inputEndedConn:Disconnect()
		end
	end, {props.KeyCode, enabled, baseSize, downScale, props.OnClick} :: {any})

	React.useEffect(function()
		return function()
			if currentTweenRef.current then
				currentTweenRef.current:Cancel()
				currentTweenRef.current:Destroy()
				currentTweenRef.current = nil
			end
		end
	end, {})

	local elementProps = table.clone(props)
	elementProps.Enabled = nil
	elementProps.SfxEnabled = nil
	elementProps.UpScale = nil
	elementProps.DownScale = nil
	elementProps.TweenInfo = nil
	elementProps.KeyCode = nil
	elementProps.OnClick = nil

	elementProps.ref = buttonRef
	elementProps[React.Event.MouseEnter] = onMouseEnter
	elementProps[React.Event.MouseLeave] = onMouseLeave
	elementProps[React.Event.MouseButton1Down] = onMouseButton1Down
	elementProps[React.Event.MouseButton1Up] = onMouseButton1Up

	return React.createElement("TextButton", elementProps)
end

return Button
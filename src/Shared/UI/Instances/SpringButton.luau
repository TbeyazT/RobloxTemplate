--!strict
const RunService = game:GetService("RunService")

const SoundController = require("@Controllers/SoundController/Client")

const RunContext = require("@Pckgs/RunContext")
const Ripple = require("@Pckgs/Ripple")
const React = require("@Pckgs/React")

type Props = {
    Position: UDim2?,
    Size: UDim2?,
    AnchorPoint: Vector2?,
    ZIndex: number?,
    BackgroundTransparency: number?,
    BackgroundColor3: Color3?,
    ClipsDescendants: boolean?,
    HoverScale: number,
    PressScale: number, 
    OnClick: (() -> ())?,
    [any]: any,
}

local function useSpring(initialValue: number, config: any?)
    local binding, setBinding = React.useBinding(initialValue)
    local springRef = React.useRef(nil :: any)

    if not springRef.current then
        springRef.current = Ripple.createSpring(initialValue, config)
    end

    local spring = springRef.current

    React.useEffect(function()
        local connection = RunService.RenderStepped:Connect(function(dt)
            local currentValue = spring:step(dt)
            setBinding(currentValue)
        end)

        return function()
            if connection then
                connection:Disconnect()
            end
        end
    end, {spring})

    local function setGoal(targetValue: number)
        spring:setGoal(targetValue)
    end

    return binding, setGoal
end

return function(props: Props)
    local isHovered, setHovered = React.useState(false)
    local isPressed, setPressed = React.useState(false)

    local buttonScale, setButtonScale = useSpring(1, { tension = 900, friction = 13 }) --13 normal

    local hoverScale = props.HoverScale or 1.05
    local pressScale = props.PressScale or 0.94

    React.useEffect(function()
        if isPressed then
            setButtonScale(pressScale)
        elseif isHovered then
            setButtonScale(hoverScale)
        else
            setButtonScale(1.0)
        end
    end, {isHovered, isPressed})

    local buttonProps = {}
    for key, value in pairs(props) do
        if key ~= "HoverScale" and key ~= "PressScale" and key ~= "OnClick" and key ~= "children" then
            buttonProps[key] = value
        end
    end

    buttonProps[React.Event.MouseEnter] = function()
        SoundController:PlaySound("Hover")
        setHovered(true)
        if props[React.Event.MouseEnter] then
            props[React.Event.MouseEnter]()
        end
    end

    buttonProps[React.Event.MouseLeave] = function()
        setHovered(false)
        setPressed(false)
        if props[React.Event.MouseLeave] then
            props[React.Event.MouseLeave]()
        end
    end

    buttonProps[React.Event.MouseButton1Down] = function()
        setPressed(true)
        if props[React.Event.MouseButton1Down] then
            props[React.Event.MouseButton1Down]()
        end
    end

    buttonProps[React.Event.Activated] = function()
        print("*20ssz0")
        SoundController:PlaySound("Click")
        setPressed(false)
        if props.OnClick then
            props.OnClick()
        end
        if props[React.Event.MouseButton1Up] then
            props[React.Event.MouseButton1Up]()
        end
    end

    local children = {}
    if type(props.children) == "table" then
        for k, v in pairs(props.children) do
            children[k] = v
        end
    end

    children.SpringButtonScale = React.createElement("UIScale", {
        Scale = buttonScale,
    })

    return React.createElement("ImageButton", buttonProps, children)
end
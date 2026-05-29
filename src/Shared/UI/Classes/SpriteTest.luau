--!strict
local React = require("@Pckgs/React")

local SpriteClass = require("@Classes/UI/SpriteSheet")

local SpriteTest = {}
SpriteTest.Order = 10 

local function Sprite()
    local labelRef = React.useRef(nil :: ImageLabel?)

    React.useEffect(function()
        local label = labelRef.current
        if not label then return end

        local config: SpriteClass.SpriteConfig = {
            SpriteSize = Vector2.new(128, 128),
            Frames = 25,                        
            Columns = 5,                        
            FPS = 30,                          
            Loop = true,                        
        }

        local spriteInstance = SpriteClass.new(label, config)
        spriteInstance:Play()

        return function()
            spriteInstance:Destroy()
        end
    end, {})

    return React.createElement("ImageLabel", {
        ref = labelRef,
        Image = "rbxassetid://131696696774706",
        Size = UDim2.fromScale(0.05, 0.1), 
        Position = UDim2.fromScale(1, 1),
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
    })
end

function SpriteTest:Init()
end

function SpriteTest:Render()
    return React.createElement(Sprite)
end

function SpriteTest:Start()
end

function SpriteTest:Destroy()
end

return SpriteTest
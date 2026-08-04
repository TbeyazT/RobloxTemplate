--!strict
const RunService = game:GetService("RunService")

const React = require("@Pckgs/React")

type Props = {
    RotationSpeed: number?, -- Speed in degrees per second (Defaults to 30)
    [any]: any,
}

return function(props: Props)
    local rotation, setRotation = React.useBinding(0)

    React.useEffect(function()
        local speed = props.RotationSpeed or 30

        local connection = RunService.PreRender:Connect(function()
            setRotation((os.clock() * speed) % 360)
        end)

        return function()
            connection:Disconnect()
        end
    end, {props.RotationSpeed})

    local imageLabelProps = {
        Image = "rbxassetid://81400641301435", --"97535043711285
    }
    for key, value in pairs(props) do
        if key ~= "RotationSpeed" and key ~= "children" then
            imageLabelProps[key] = value
        end
    end

    imageLabelProps.Rotation = rotation

    return React.createElement("ImageLabel", imageLabelProps, props.children)
end
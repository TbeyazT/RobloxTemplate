local Instance = {}

function Instance.getOriginalProperty(instance: Instance, propertyName: string): any
    local attributeName = `Original{propertyName}`
    local originalValue = instance:GetAttribute(attributeName)
    if not originalValue then
        if propertyName == "Pivot" then
            originalValue = (instance :: PVInstance):GetPivot()
        elseif propertyName == "Scale" then
            originalValue = (instance :: Model):GetScale()
        else
            originalValue = (instance :: any)[propertyName]
        end

        instance:SetAttribute(attributeName, originalValue)
    end

    return originalValue
end

return Instance
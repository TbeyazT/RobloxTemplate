return function(value, useCommas)
    -- Check if value exists before doing math on it to prevent errors
    if not value then return "0" end
    
    value = math.floor(value) 

    if value < 1000 then return tostring(value) end

    -- If the useCommas option is true, format like "1,500,000"
    if useCommas then
        local formatted = tostring(value)
        while true do  
            local k
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
            if (k == 0) then
                break
            end
        end
        return formatted
    end

    -- Otherwise, use the Suffix formatting like "1.5M"
    local suffixes = {"K", "M", "B", "T", "Qa", "Qi"}
    local index = math.floor(math.log10(value) / 3)
    local divisor = 10 ^ (index * 3)

    local formatted = string.format("%.2f", value / divisor)
    formatted = formatted:gsub("%.?0+$", "")
    
    return formatted .. (suffixes[index] or "")
end
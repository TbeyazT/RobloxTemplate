local TextService = game:GetService("TextService")

local React = require("@Pckgs/React")

--// Types
export type LetterData = {
    Char: string,
    Position: UDim2,
    Size: UDim2,
    Index: number,
    WordIndex: number,
    TextSize: number,
}

export type WordData = {
    WordString: string,
    Position: UDim2,
    Size: UDim2,
    Index: number,
    Letters: { LetterData },
    TextSize: number,
}

export type RichTextLabelProps = {
    Text: string,
    TextSize: number?,
    Font: Enum.Font?,
    FontFace: Font?,
    TextColor3: Color3?,
    TextScaled: boolean?,
    TextXAlignment: Enum.TextXAlignment?,
    TextYAlignment: Enum.TextYAlignment?,
    TextTransparency: number?,
    Size: UDim2?,
    Position: UDim2?,
    AnchorPoint: Vector2?,
    ZIndex: number?,
    ClipsDescendants: boolean?,
    LayoutOrder: number?,
    onWordsCreated: ((words: { WordData }, letters: { LetterData }) -> ())?,
    renderLetter: ((letter: LetterData) -> any)?,
    renderWord: ((word: WordData, letterElements: { [string]: any }) -> any)?,
}

local function getAccurateTextSize(text: string, size: number, fontEnum: Enum.Font?, fontFace: Font?, frameSize: Vector2): Vector2
    if fontFace then
        local params = Instance.new("GetTextBoundsParams")
        params.Text = text
        params.Size = size
        params.Font = fontFace
        params.Width = (frameSize.X < math.huge) and frameSize.X or 0
        local bounds = TextService:GetTextBoundsAsync(params)
        TextService:GetTextBoundsAsync(params)
        params:Destroy()
        return bounds
    end

    local fontToUse = fontEnum or Enum.Font.SourceSans
    if fontToUse == Enum.Font.Unknown then
        fontToUse = Enum.Font.SourceSans
    end
    return TextService:GetTextSize(text, size, fontToUse, frameSize)
end

local function calculateBestFontSize(text: string, fontEnum: Enum.Font?, fontFace: Font?, frameSize: Vector2): number
    local minSize = 1
    local maxSize = 100
    local bestSize = minSize

    local layoutConstraint = Vector2.new(frameSize.X, 10000)

    while minSize <= maxSize do
        local mid = math.floor((minSize + maxSize) / 2)
        local bounds = getAccurateTextSize(text, mid, fontEnum, fontFace, layoutConstraint)

        if bounds.X <= frameSize.X and bounds.Y <= frameSize.Y then
            bestSize = mid
            minSize = mid + 1
        else
            maxSize = mid - 1
        end
    end

    return bestSize
end

local function getKeywordLetters(letters: { LetterData }, keyword: string, ignoreCase: boolean?): { LetterData }
    local results = {}
    if not keyword or keyword == "" then return results end

    local cleanKeyword = keyword:gsub("%s+", "")
    local keywordChars = {}
    for first, last in utf8.graphemes(cleanKeyword) do
        local char = string.sub(cleanKeyword, first, last)
        if ignoreCase then char = string.lower(char) end
        table.insert(keywordChars, char)
    end

    local keyLen = #keywordChars
    if keyLen == 0 then return results end

    local i = 1
    while i <= #letters do
        if (i + keyLen - 1) > #letters then break end

        local match = true
        for k = 1, keyLen do
            local letterObj = letters[i + k - 1]
            local letterChar = letterObj.Char
            if ignoreCase then letterChar = string.lower(letterChar) end

            if letterChar ~= keywordChars[k] then
                match = false
                break
            end
        end

        if match then
            for k = 1, keyLen do
                table.insert(results, letters[i + k - 1])
            end
            i = i + keyLen
        else
            i = i + 1
        end
    end

    return results
end

local function RichTextLabel(props: RichTextLabelProps)
    local text = props.Text or ""
    local textSize = props.TextSize or 24
    local fontEnum = props.Font or Enum.Font.SourceSans
    local fontFace = props.FontFace
    local textColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
    local textScaled = props.TextScaled or false
    local textXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    local textYAlignment = props.TextYAlignment or Enum.TextYAlignment.Top
    local textTransparency = props.TextTransparency or 0
    local zIndex = props.ZIndex or 1

    local containerSize, setContainerSize = React.useState(Vector2.zero)

    local words, letters = React.useMemo(function()
        if not text or text == "" or containerSize.X <= 1 or containerSize.Y <= 1 then
            return {}, {}
        end

        local actualTextSize = if textScaled
            then calculateBestFontSize(text, fontEnum, fontFace, containerSize)
            else textSize

        local lineHeight = actualTextSize * 1.0
        local rawLines = text:split("\n")
        local lines = {}
        local bigVector = Vector2.new(math.huge, math.huge)

        for _, rawLineStr in ipairs(rawLines) do
            if rawLineStr == "" then
                table.insert(lines, { Width = 0, Tokens = {} })
                continue
            end

            local currentLine = { Width = 0, Tokens = {} }
            local currentLineString = ""

            local tokens = {}
            local tempStr = ""
            for first, last in utf8.graphemes(rawLineStr) do
                local char = string.sub(rawLineStr, first, last)
                if char == " " then
                    if tempStr ~= "" then table.insert(tokens, { Text = tempStr, IsSpace = false }) tempStr = "" end
                    table.insert(tokens, { Text = " ", IsSpace = true })
                else
                    tempStr = tempStr .. char
                end
            end
            if tempStr ~= "" then table.insert(tokens, { Text = tempStr, IsSpace = false }) end

            for _, token in ipairs(tokens) do
                local textToAdd = token.Text
                local testString = currentLineString .. textToAdd
                local testBounds = getAccurateTextSize(testString, actualTextSize, fontEnum, fontFace, bigVector)

                if testBounds.X > containerSize.X and #currentLine.Tokens > 0 then
                    currentLine.Width = getAccurateTextSize(currentLineString, actualTextSize, fontEnum, fontFace, bigVector).X
                    table.insert(lines, currentLine)

                    currentLine = { Width = 0, Tokens = {} }
                    currentLineString = ""

                    if token.IsSpace then
                        continue
                    end
                end

                table.insert(currentLine.Tokens, token)
                currentLineString = currentLineString .. textToAdd
            end

            if #currentLine.Tokens > 0 then
                currentLine.Width = getAccurateTextSize(currentLineString, actualTextSize, fontEnum, fontFace, bigVector).X
                table.insert(lines, currentLine)
            end
        end

        local totalContentHeight = #lines * lineHeight
        local startYOffset = 0

        if textYAlignment == Enum.TextYAlignment.Center then
            startYOffset = (containerSize.Y - totalContentHeight) / 2
        elseif textYAlignment == Enum.TextYAlignment.Bottom then
            startYOffset = containerSize.Y - totalContentHeight
        end

        local calculatedWords: { WordData } = {}
        local calculatedLetters: { LetterData } = {}
        local globalWordIndex = 1
        local globalLetterIndex = 1

        for lineIndex, lineData in ipairs(lines) do
            local startXOffset = 0
            if textXAlignment == Enum.TextXAlignment.Center then
                startXOffset = (containerSize.X - lineData.Width) / 2
            elseif textXAlignment == Enum.TextXAlignment.Right then
                startXOffset = containerSize.X - lineData.Width
            end

            local currentY = startYOffset + ((lineIndex - 1) * lineHeight)
            local lineBuildString = ""

            for _, token in ipairs(lineData.Tokens) do
                local prevWidth = 0
                if lineBuildString ~= "" then
                    prevWidth = getAccurateTextSize(lineBuildString, actualTextSize, fontEnum, fontFace, bigVector).X
                end

                local tokenWidth = getAccurateTextSize(token.Text, actualTextSize, fontEnum, fontFace, bigVector).X

                if token.IsSpace then
                    lineBuildString = lineBuildString .. token.Text
                else
                    local wScale = tokenWidth / containerSize.X
                    local hScale = actualTextSize / containerSize.Y
                    local xScale = (startXOffset + prevWidth) / containerSize.X
                    local yScale = currentY / containerSize.Y

                    local wordObj: WordData = {
                        WordString = token.Text,
                        Position = UDim2.new(xScale, 0, yScale, 0),
                        Size = UDim2.new(wScale, 0, hScale, 0),
                        Letters = {},
                        Index = globalWordIndex,
                        TextSize = actualTextSize,
                    }

                    local localXCursor = 0
                    for first, last in utf8.graphemes(token.Text) do
                        local char = string.sub(token.Text, first, last)
                        local charSize = getAccurateTextSize(char, actualTextSize, fontEnum, fontFace, bigVector)

                        local charScaleRel = charSize.X / tokenWidth
                        local xPosRel = localXCursor / tokenWidth

                        local letterObj: LetterData = {
                            Char = char,
                            Position = UDim2.new(xPosRel, 0, 0, 0),
                            Size = UDim2.new(charScaleRel, 0, 1, 0),
                            Index = globalLetterIndex,
                            WordIndex = globalWordIndex,
                            TextSize = actualTextSize,
                        }

                        table.insert(wordObj.Letters, letterObj)
                        table.insert(calculatedLetters, letterObj)

                        localXCursor += charSize.X
                        globalLetterIndex += 1
                    end

                    table.insert(calculatedWords, wordObj)
                    lineBuildString = lineBuildString .. token.Text
                    globalWordIndex += 1
                end
            end
        end

        return calculatedWords, calculatedLetters
    end, { text, textSize, textScaled, fontEnum, fontFace, containerSize, textXAlignment, textYAlignment })

    React.useEffect(function()
        if props.onWordsCreated and #words > 0 then
            props.onWordsCreated(words, letters)
        end
    end, { words, letters })

    local wordElements = {}
    for _, word in ipairs(words) do
        local letterElements = {}

        for _, letter in ipairs(word.Letters) do
            if props.renderLetter then
                letterElements["Char_" .. letter.Index] = props.renderLetter(letter)
            else
                local labelProps: { [string]: any } = {
                    Text = letter.Char,
                    TextColor3 = textColor3,
                    TextSize = word.TextSize,
                    TextScaled = false,
                    BackgroundTransparency = 1,
                    TextTransparency = textTransparency,
                    Size = letter.Size,
                    Position = letter.Position,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Center,
                    ZIndex = zIndex,
                }

                if fontFace then
                    labelProps.FontFace = fontFace
                else
                    labelProps.Font = fontEnum
                end

                letterElements["Char_" .. letter.Index] = React.createElement("TextLabel", labelProps)
            end
        end

        if props.renderWord then
            wordElements["Word_" .. word.Index] = props.renderWord(word, letterElements)
        else
            wordElements["Word_" .. word.Index] = React.createElement("Frame", {
                BackgroundTransparency = 1,
                Size = word.Size,
                Position = word.Position,
            }, letterElements)
        end
    end

    return React.createElement("Frame", {
        Size = props.Size or UDim2.fromScale(1, 1),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        BackgroundTransparency = 1,
        ClipsDescendants = props.ClipsDescendants,
        ZIndex = zIndex,
        LayoutOrder = props.LayoutOrder,
        [React.Change.AbsoluteSize] = function(rbx)
            if rbx.AbsoluteSize ~= containerSize then
                setContainerSize(rbx.AbsoluteSize)
            end
        end,
        ref = function(rbx: Frame?)
            if rbx and rbx.AbsoluteSize ~= Vector2.zero and rbx.AbsoluteSize ~= containerSize then
                setContainerSize(rbx.AbsoluteSize)
            end
        end,
    }, wordElements)
end

return {
    App = RichTextLabel,
    getKeywordLetters = getKeywordLetters,
}
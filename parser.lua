-- parser.lua
-- Parseur HTML simple creant une arborescence DOM

local parser = {}

function parser.parse(html)
    local nodes = {}
    local stack = {}
    local current = nodes
    
    local i = 1
    local len = #html
    
    while i <= len do
        local tagStart = html:find("<", i)
        
        if not tagStart then
            local text = html:sub(i)
            if text:match("%S") then
                table.insert(current, {type="text", value=text})
            end
            break
        end
        
        if tagStart > i then
            local text = html:sub(i, tagStart - 1)
            if text:match("%S") then
                table.insert(current, {type="text", value=text})
            end
        end
        
        local tagEnd = html:find(">", tagStart)
        if not tagEnd then break end
        
        local tagContent = html:sub(tagStart + 1, tagEnd - 1)
        i = tagEnd + 1
        
        local isClosing = tagContent:sub(1, 1) == "/"
        if isClosing then tagContent = tagContent:sub(2) end
        
        local tagName = tagContent:match("^([%w%-]+)")
        if tagName then
            tagName = tagName:lower()
            local attributes = {}
            local attrString = tagContent:sub(#tagName + 1)
            for k, v in attrString:gmatch("(%w+)%s*=%s*[\"']([^\"']+)[\"']") do
                attributes[k:lower()] = v
            end
            for k, v in attrString:gmatch("(%w+)%s*=%s*([^%s\"'>]+)") do
                if not attributes[k:lower()] then attributes[k:lower()] = v end
            end
            
            if isClosing then
                if #stack > 0 then current = table.remove(stack) end
            else
                local node = {
                    type = "element", tag = tagName,
                    attributes = attributes, children = {}
                }
                table.insert(current, node)
                
                local selfClosing = {img=true, br=true, input=true, hr=true}
                if not selfClosing[tagName] and tagContent:sub(-1) ~= "/" then
                    table.insert(stack, current)
                    current = node.children
                end
            end
        end
    end
    return nodes
end

return parser

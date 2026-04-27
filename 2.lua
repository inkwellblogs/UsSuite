-- Mobile friendly dump with output visible
local HttpService = game:GetService("HttpService")
local seen = {}

local function dumpStructure(obj, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 2  -- Mobile mein kam depth
    if depth > maxDepth then return "" end
    if seen[obj] then return "" end
    seen[obj] = true
    
    local result = ""
    local indent = string.rep("  ", depth)
    
    for _, child in ipairs(obj:GetChildren()) do
        result = result .. indent .. child.Name .. " [" .. child.ClassName .. "]"
        pcall(function()
            local attrs = child:GetAttributes()
            if next(attrs) then
                result = result .. " {"
                for k, v in pairs(attrs) do result = result .. k .. "=" .. tostring(v) .. ", " end
                result = result .. "}"
            end
        end)
        result = result .. "\n"
        if #child:GetChildren() > 0 then
            result = result .. dumpStructure(child, depth + 1, maxDepth)
        end
    end
    return result
end

-- Sirf important parts
seen = {}
local fullDump = "=== WORKSPACE ===\n"
for _, child in ipairs(workspace:GetChildren()) do
    if not string.find(child.Name, "Tree") and not string.find(child.Name, "House") and not string.find(child.Name, "Barrier") then
        fullDump = fullDump .. child.Name .. " [" .. child.ClassName .. "]"
        if child.Name == "Unclimbable" or child.Name == "Titans" or child.Name == "Characters" then
            fullDump = fullDump .. "\n" .. dumpStructure(child, 1, 3)
        elseif child.Name ~= "Camera" and child.Name ~= "Terrain" then
            fullDump = fullDump .. "\n" .. dumpStructure(child, 1, 2)
        end
        fullDump = fullDump .. "\n"
    end
end

fullDump = fullDump .. "\n=== INTERFACE ===\n"
pcall(function()
    local interface = lp.PlayerGui:FindFirstChild("Interface")
    if interface then
        fullDump = fullDump .. dumpStructure(interface, 0, 2)
    end
end)

-- Clipboard mein copy (mobile supported)
setclipboard(fullDump)
print("=== DUMP COPIED TO CLIPBOARD ===")
print("Size: " .. #fullDump .. " chars")
print("Paste it in chat or notes app!")

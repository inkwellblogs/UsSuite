-- Workspace Structure Dumper - Clean version
local HttpService = game:GetService("HttpService")
local seen = {}

local function dumpStructure(obj, depth, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 3
    if depth > maxDepth then return "" end
    if seen[obj] then return "" end
    seen[obj] = true
    
    local result = ""
    local indent = string.rep("  ", depth)
    
    for _, child in ipairs(obj:GetChildren()) do
        -- Skip excessive tree/leaf models
        if child.Name == "Trees" or child.Name == "Leaves" or child.Name == "Pine" or child.Name == "Oak" then
            result = result .. indent .. child.Name .. " [" .. child.ClassName .. "] (" .. #child:GetChildren() .. " children)\n"
        else
            result = result .. indent .. child.Name .. " [" .. child.ClassName .. "]"
            
            -- Show attributes
            pcall(function()
                local attrs = child:GetAttributes()
                if next(attrs) then
                    local attrStr = ""
                    for k, v in pairs(attrs) do
                        attrStr = attrStr .. k .. "=" .. tostring(v) .. ", "
                    end
                    result = result .. " {" .. attrStr .. "}"
                end
            end)
            
            result = result .. "\n"
            
            -- Go deeper
            if #child:GetChildren() > 0 then
                result = result .. dumpStructure(child, depth + 1, maxDepth)
            end
        end
    end
    return result
end

-- Clear seen for each major section
local function dumpSection(name, obj, depth)
    seen = {}
    return "\n=== " .. name .. " ===\n" .. dumpStructure(obj, 0, depth or 3)
end

-- Collect everything
local fullDump = ""

-- Workspace (depth 3)
fullDump = fullDump .. dumpSection("WORKSPACE", workspace, 3)

-- ReplicatedStorage (depth 2 - only important parts)
seen = {}
fullDump = fullDump .. "\n=== REPLICATED STORAGE (Main Folders) ===\n"
local rs = game:GetService("ReplicatedStorage")
local assets = rs:FindFirstChild("Assets")
if assets then
    for _, child in ipairs(assets:GetChildren()) do
        if child.Name == "Remotes" then
            fullDump = fullDump .. "  Remotes [Folder]\n"
            for _, rem in ipairs(child:GetChildren()) do
                fullDump = fullDump .. "    " .. rem.Name .. " [" .. rem.ClassName .. "]\n"
            end
        elseif child.Name == "Effects" or child.Name == "Customisation" or child.Name == "Skills" or child.Name == "Blades" or child.Name == "Spears" or child.Name == "Rigs" or child.Name == "3DMGs" or child.Name == "Cannisters" or child.Name == "Artifacts" or child.Name == "Auras" or child.Name == "Cutscenes" then
            fullDump = fullDump .. "  " .. child.Name .. " [Folder] (" .. #child:GetChildren() .. " items)\n"
        end
    end
end

-- PlayerGui Interface (depth 3)
seen = {}
local interface = lp.PlayerGui:FindFirstChild("Interface")
if interface then
    fullDump = fullDump .. dumpSection("PLAYER GUI / INTERFACE", interface, 3)
end

-- Save to file and clipboard
local fileName = "workspace_dump_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
writefile(fileName, fullDump)
setclipboard(fullDump)

print("=== DUMP COMPLETE ===")
print("File saved: " .. fileName)
print("Also copied to clipboard!")
print("Total size: " .. #fullDump .. " characters")
print("Total lines: " .. select(2, fullDump:gsub("\n", "\n")))

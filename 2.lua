-- Save workspace structure to clipboard
local function dumpStructure(obj, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local result = ""
    
    for _, child in ipairs(obj:GetChildren()) do
        result = result .. indent .. child.Name .. " [" .. child.ClassName .. "]"
        
        -- Show attributes if any
        pcall(function()
            local attrs = child:GetAttributes()
            if next(attrs) then
                result = result .. " {"
                for k, v in pairs(attrs) do
                    result = result .. k .. "=" .. tostring(v) .. ", "
                end
                result = result .. "}"
            end
        end)
        
        result = result .. "\n"
        
        -- Go deeper for important folders
        if #child:GetChildren() > 0 and depth < 4 then
            result = result .. dumpStructure(child, depth + 1)
        end
    end
    return result
end

local dump = "=== WORKSPACE ===\n" .. dumpStructure(workspace)
dump = dump .. "\n=== REPLICATED STORAGE (Assets/Remotes) ===\n"
pcall(function()
    local rs = game:GetService("ReplicatedStorage")
    local assets = rs:FindFirstChild("Assets")
    if assets then
        dump = dump .. dumpStructure(assets, 1)
    end
end)

dump = dump .. "\n=== INTERFACE ===\n"
pcall(function()
    local interface = lp.PlayerGui:FindFirstChild("Interface")
    if interface then
        dump = dump .. dumpStructure(interface, 1)
    end
end)

setclipboard(dump)
print("Structure copied to clipboard! Paste it here.")
print("Total length:", #dump)

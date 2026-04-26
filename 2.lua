-- Find Refill in new update
print("===== FINDING REFILL =====")
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name == "Refill" or obj.Name == "GasTanks" or obj.Name == "Reloads" then
        print("Found:", obj:GetFullName(), "| Class:", obj.ClassName)
    end
end

-- Check Points folder
local points = workspace:FindFirstChild("Points")
if points then
    print("\n--- Points Children ---")
    for _, child in ipairs(points:GetChildren()) do
        print("  ", child.Name, child.ClassName)
        if child.Name == "Refill" then
            print("  >>> REFILL FOUND IN POINTS!")
        end
    end
end

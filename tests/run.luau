local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Rules = require("../src/Rules")
local count = 0
local function test(name, callback)
    local ok, err = pcall(callback)
    assert(ok, name .. ": " .. tostring(err))
    count += 1
    print("PASS " .. name)
end
local function rejects(callback)
    assert(not pcall(callback), "expected an error")
end
for _, name in ipairs(fs.readDir("src")) do
    if name:match("%.luau$") then luau.compile(fs.readFile("src/" .. name)) end
end


local roblox = require("@lune/roblox")
local gameRoot = { Name = "Game", children = {} }
function gameRoot:IsA(class) return class == "DataModel" end
local function object(name, parent, class)
    local node = { Name = name, Parent = parent, ClassName = class or "Folder", children = {}, Locked = false,
        Material = roblox.Enum.Material.Plastic, MaterialVariant = "", Size = roblox.Vector3.new(2, 2, 2),
        CFrame = roblox.CFrame.new(), Color = roblox.Color3.new(0.2, 0.4, 0.6), TextureID = "example-texture",
        CustomPhysicalProperties = { marker = "unchanged" },
    }
    function node:IsA(candidate)
        if candidate == self.ClassName then return true end
        if candidate == "BasePart" then return self.ClassName == "Part" or self.ClassName == "MeshPart" or self.ClassName == "Terrain" end
        if candidate == "WorldRoot" or candidate == "Model" then return self.ClassName == "WorldModel" or self.ClassName == "Workspace" end
        return false
    end
    function node:IsDescendantOf(ancestor)
        local cursor = self.Parent
        while cursor do if cursor == ancestor then return true end cursor = cursor.Parent end
        return false
    end
    function node:FindFirstAncestorWhichIsA(class)
        local cursor = self.Parent
        while cursor do if cursor:IsA(class) then return cursor end cursor = cursor.Parent end
        return nil
    end
    function node:GetChildren() return self.children end
    function node:GetFullName()
        local names, cursor = {}, self
        while cursor and cursor ~= gameRoot do table.insert(names, 1, cursor.Name) cursor = cursor.Parent end
        return table.concat(names, ".")
    end
    if parent then table.insert(parent.children, node) end
    return node
end
local world = object("Workspace", gameRoot, "Workspace")
local Scope = luau.load(fs.readFile("src/Scope.luau"), { environment = { game = gameRoot } })()
local modules = { Rules = Rules, Scope = Scope }
local Adapter = luau.load(fs.readFile("src/Adapter.luau"), { environment = {
    require = function(name) assert(modules[name]) return modules[name] end,
    script = { Parent = { Rules = "Rules", Scope = "Scope" } }, game = gameRoot, workspace = world,
    Enum = roblox.Enum, Vector3 = roblox.Vector3,
} })()
local function near(a, b)
    assert(math.abs(a - b) < 0.0001, tostring(a) .. " differs from " .. tostring(b))
end
test("scope deduplicates overlapping roots", function()
    local folder = object("Folder", world)
    local a, b = object("A", folder), object("B", folder)
    local targets, scanned = Scope.collect({ folder, a }, true, function() return true end)
    assert(#targets == 3 and scanned == 3 and targets[1] == folder and targets[2] == b and targets[3] == a)
    local only = Scope.collect({ folder }, false, function() return true end)
    assert(#only == 1)
end)
test("scope rejects detached roots, services and empty selections", function()
    rejects(function() Scope.collect({}, true, function() return true end) end)
    rejects(function() Scope.collect({ world }, true, function() return true end) end)
    rejects(function() Scope.collect({ object("Detached", nil) }, true, function() return true end) end)
end)
test("scope limits discovered objects before returning partial results", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return false end, { maxNodes = 2, maxTargets = 2 }) end)
end)
test("scope target limit is independent of scan limit", function()
    local folder = object("Folder", world)
    object("A", folder) object("B", folder)
    rejects(function() Scope.collect({ folder }, true, function() return true end, { maxNodes = 10, maxTargets = 2 }) end)
end)


test("local sizes, aggregate bounds and Size-box volume are reported", function()
    local part = object("Part", world, "Part") part.Size = roblox.Vector3.new(2, 4, 6)
    local before = part.CFrame
    local report = Adapter.measure({ part }, { decimals = 3 })
    near(report.extent.X, 2) near(report.extent.Y, 4) near(report.extent.Z, 6)
    near(report.center.X, 0) near(report.summedBoxVolume, 48)
    assert(report.originDistance == nil and part.CFrame == before and part.Size == roblox.Vector3.new(2, 4, 6))
end)
test("rotated part corners produce world-axis bounds", function()
    local part = object("Part", world, "Part") part.Size = roblox.Vector3.new(2, 4, 6)
    part.CFrame = roblox.CFrame.Angles(0, math.pi / 2, 0)
    local report = Adapter.measure({ part }, { decimals = 3 })
    near(report.extent.X, 6) near(report.extent.Y, 4) near(report.extent.Z, 2)
    part.Size = roblox.Vector3.new(2, 2, 2) part.CFrame = roblox.CFrame.Angles(0, math.pi / 4, 0)
    report = Adapter.measure({ part }, { decimals = 3 })
    near(report.extent.X, 2 * math.sqrt(2)) near(report.extent.Z, 2 * math.sqrt(2))
end)
test("two separated parts have known origin and box-gap distances", function()
    local a, b = object("A", world, "Part"), object("B", world, "Part")
    b.CFrame = roblox.CFrame.new(5, 0, 0)
    local report = Adapter.measure({ a, b }, { decimals = 3 })
    near(report.originDistance, 5) near(report.boxGap, 3) near(report.extent.X, 7) near(report.summedBoxVolume, 16)
end)
test("diagonal gaps use all three world axes", function()
    local a, b = object("A", world, "Part"), object("B", world, "Part") b.CFrame = roblox.CFrame.new(5, 6, 0)
    local report = Adapter.measure({ a, b }, { decimals = 3 })
    near(report.gap.X, 3) near(report.gap.Y, 4) near(report.gap.Z, 0) near(report.boxGap, 5)
    near(report.originDistance, math.sqrt(61))
end)
test("overlapping or touching boxes have zero box gap", function()
    local a, b = object("A", world, "Part"), object("B", world, "Part")
    for _, offset in ipairs({ 1, 2 }) do
        b.CFrame = roblox.CFrame.new(offset, 0, 0)
        near(Adapter.measure({ a, b }, { decimals = 3 }).boxGap, 0)
    end
end)
test("formatting respects precision and does not display negative zero", function()
    local part = object("Part", world, "Part") part.CFrame = roblox.CFrame.new(-0.00000001, 0, 0)
    local report = Adapter.measure({ part }, { decimals = 3 })
    local summary, labels = Adapter.format(report)
    assert(summary:find("2.000", 1, true) and not labels[1]:find("-0.000", 1, true))
    rejects(function() Adapter.measure({ part }, { decimals = 7 }) end)
end)
test("nested selections are deduplicated and locked parts remain measurable", function()
    local folder = object("Folder", world)
    local part = object("Part", folder, "Part") part.Locked = true
    assert(#Adapter.measure({ folder, part }, { decimals = 3, expand = true }).rows == 1)
end)
test("other worlds, Terrain and empty selections are refused", function()
    local other = object("Other", world, "WorldModel") local part = object("Part", other, "Part")
    rejects(function() Adapter.measure({ part }, { decimals = 3 }) end)
    rejects(function() Adapter.measure({ object("Terrain", world, "Terrain") }, { decimals = 3 }) end)
    rejects(function() Adapter.measure({}, { decimals = 3 }) end)
end)
test("invalid geometry and oversized reports are rejected", function()
    rejects(function() Rules.bounds({}) end)
    local corners = table.create(8, { X = 0, Y = 0, Z = 0 })
    corners[1] = { X = 0 / 0, Y = 0, Z = 0 }
    rejects(function() Rules.bounds(corners) end)
    rejects(function() Rules.report(table.create(1001, {})) end)
    local part = object("Part", world, "Part") part.Size = roblox.Vector3.new(0, 2, 2)
    rejects(function() Adapter.measure({ part }, { decimals = 3 }) end)
end)
test("display limits do not exclude parts from aggregate measurements", function()
    local folder = object("Folder", world)
    for index = 0, 100 do local part = object(tostring(index), folder, "Part") part.CFrame = roblox.CFrame.new(index, 0, 0) end
    local report = Adapter.measure({ folder }, { decimals = 3, expand = true })
    local _, labels = Adapter.format(report)
    assert(#report.rows == 101 and #labels == 100) near(report.extent.X, 102)
end)

print(string.format("%d checks passed", count))

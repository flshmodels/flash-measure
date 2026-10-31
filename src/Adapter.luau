local Rules = require(script.Parent.Rules)
local Scope = require(script.Parent.Scope)
local Adapter = {}

function Adapter.measure(selection, options)
    assert(type(options.decimals) == "number" and options.decimals % 1 == 0 and options.decimals >= 0 and options.decimals <= 6, "Decimal places must be from 0 to 6.")
    local parts, scanned = Scope.collect(selection, options.expand, function(object)
        return object:IsA("BasePart") and not object:IsA("Terrain") and object:IsDescendantOf(workspace)
            and object:FindFirstAncestorWhichIsA("WorldRoot") == workspace
    end)
    local records = {}
    for _, part in ipairs(parts) do
        local frame, size = part.CFrame, part.Size
        local corners = {}
        for _, x in ipairs({ -1, 1 }) do
            for _, y in ipairs({ -1, 1 }) do
                for _, z in ipairs({ -1, 1 }) do
                    table.insert(corners, frame:PointToWorldSpace(Vector3.new(x * size.X / 2, y * size.Y / 2, z * size.Z / 2)))
                end
            end
        end
        table.insert(records, { target = part, path = part:GetFullName(), origin = frame.Position, size = size, corners = corners })
    end
    local result = Rules.report(records)
    result.scanned = scanned
    result.decimals = options.decimals
    return result
end

function Adapter.format(result)
    local format = "%." .. tostring(result.decimals) .. "f"
    local function number(value)
        if math.abs(value) < 0.5 * 10 ^ -result.decimals then value = 0 end
        return string.format(format, value)
    end
    local function vector(value)
        return number(value.X) .. ", " .. number(value.Y) .. ", " .. number(value.Z)
    end
    local summary = {
        string.format("%d parts / %d objects scanned. Snapshot only; nothing was edited.", #result.rows, result.scanned),
        "World-axis box size (studs): " .. vector(result.extent),
        "World-axis box center: " .. vector(result.center),
        "Summed Size-box volume (studs cubed): " .. number(result.summedBoxVolume),
    }
    if result.originDistance then
        table.insert(summary, "Two-part CFrame-origin distance: " .. number(result.originDistance))
        table.insert(summary, "World-box gaps X, Y, Z: " .. vector(result.gap))
        table.insert(summary, "World-box gap length: " .. number(result.boxGap) .. " (not a surface-distance measurement)")
    end
    local labels = {}
    for index, row in ipairs(result.rows) do
        if index > 100 then break end
        labels[index] = row.path .. "\nLocal Size: " .. vector(row.size) .. "\nCFrame origin: " .. vector(row.origin)
    end
    return table.concat(summary, "\n"), labels
end

return Adapter

local Rules = {}
local axes = { "X", "Y", "Z" }

local function coordinate(value)
    return type(value) == "number" and value == value and math.abs(value) <= 1000000
end

function Rules.bounds(corners)
    assert(#corners == 8, "A part box needs eight corners.")
    local minimum = { X = math.huge, Y = math.huge, Z = math.huge }
    local maximum = { X = -math.huge, Y = -math.huge, Z = -math.huge }
    for _, corner in ipairs(corners) do
        for _, axis in ipairs(axes) do
            local value = corner[axis]
            assert(coordinate(value), "Box corners must be finite and within one million studs of the origin.")
            minimum[axis] = math.min(minimum[axis], value)
            maximum[axis] = math.max(maximum[axis], value)
        end
    end
    return minimum, maximum
end

function Rules.report(records)
    assert(#records > 0 and #records <= 1000, "Choose between 1 and 1000 eligible Workspace parts.")
    local minimum = { X = math.huge, Y = math.huge, Z = math.huge }
    local maximum = { X = -math.huge, Y = -math.huge, Z = -math.huge }
    local rows, boxVolume = {}, 0
    for _, record in ipairs(records) do
        for _, axis in ipairs(axes) do
            assert(coordinate(record.origin[axis]), "Part origins must be finite and within one million studs.")
            assert(coordinate(record.size[axis]) and record.size[axis] > 0, "Part sizes must be positive, finite and at most one million studs per axis.")
        end
        local low, high = Rules.bounds(record.corners)
        local volume = record.size.X * record.size.Y * record.size.Z
        boxVolume += volume
        table.insert(rows, { target = record.target, path = record.path, origin = record.origin, size = record.size, minimum = low, maximum = high, boxVolume = volume })
        for _, axis in ipairs(axes) do
            minimum[axis] = math.min(minimum[axis], low[axis])
            maximum[axis] = math.max(maximum[axis], high[axis])
        end
    end
    local extent, center = {}, {}
    for _, axis in ipairs(axes) do
        extent[axis] = maximum[axis] - minimum[axis]
        center[axis] = (maximum[axis] + minimum[axis]) / 2
    end
    local result = { rows = rows, minimum = minimum, maximum = maximum, extent = extent, center = center, summedBoxVolume = boxVolume }
    if #rows == 2 then
        local squaredDistance, squaredGap = 0, 0
        local gap = {}
        for _, axis in ipairs(axes) do
            squaredDistance += (rows[1].origin[axis] - rows[2].origin[axis]) ^ 2
            gap[axis] = math.max(0, rows[1].minimum[axis] - rows[2].maximum[axis], rows[2].minimum[axis] - rows[1].maximum[axis])
            squaredGap += gap[axis] ^ 2
        end
        result.originDistance = math.sqrt(squaredDistance)
        result.gap = gap
        result.boxGap = math.sqrt(squaredGap)
    end
    return result
end

return Rules

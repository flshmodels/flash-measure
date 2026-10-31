if not plugin then return end

local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")
local Ui = require(script.Ui)
local Adapter = require(script.Adapter)
local panel = Ui.new(plugin, "FlashMeasure", "Flash Measure", "Measure")
panel.label("Measure part Size boxes in studs. Rotated parts are included in the world-axis bounds. Mesh surfaces, collision geometry and actual solid volume are not measured.")
local rows, results = {}, {}
local status
local function clear()
    results = {}
    for _, row in ipairs(rows) do row.Visible = false end
    if status then status.Text = "Options changed. Measure again." end
end
local expand = panel.cycle("Scope", { "Selection only", "Include descendants" }, clear)
local decimals = panel.field("Decimal places (0-6)", "3")
decimals:GetPropertyChangedSignal("Text"):Connect(clear)
status = panel.label("Select parts, or select a Model and include descendants. Exactly two parts also show origin distance and box gaps.")
panel.button("Measure selection", function()
    clear()
    if RunService:IsRunning() then status.Text = "Stop the play test first." return end
    local ok, result = pcall(Adapter.measure, Selection:Get(), { expand = expand() == "Include descendants", decimals = tonumber(decimals.Text) })
    if not ok then status.Text = tostring(result) return end
    results = result.rows
    local summary, labels = Adapter.format(result)
    status.Text = summary .. "\nShowing up to 100 parts. Click a row to select it. Measure again after edits."
    for index, text in ipairs(labels) do rows[index].Text = text rows[index].Visible = true end
end)
for index = 1, 100 do
    local slot = index
    local row = panel.button("", function()
        local result = results[slot]
        if result and result.target:IsDescendantOf(game) then
            Selection:Set({ result.target })
        else
            status.Text = "That part was removed. Measure again."
        end
    end)
    row.Size = UDim2.new(1, 0, 0, 86)
    row.TextSize = 14
    row.TextTruncate = Enum.TextTruncate.AtEnd
    row.Visible = false
    rows[index] = row
end
plugin.Unloading:Connect(function() panel.destroy() end)

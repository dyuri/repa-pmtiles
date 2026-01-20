-- Debug Lua config - ONLY hiking route relations
-- This is for debugging purposes to see if routes are being extracted at all

-- Don't process nodes
node_keys = {}

-- Helper to parse OSMC symbol
function parse_osmc(osmc)
    local trail_color = nil
    local trail_symbol = nil

    local parts = {}
    for part in (osmc .. ":"):gmatch("([^:]*):") do
        table.insert(parts, part)
    end

    if #parts >= 1 and parts[1] ~= "" then
        trail_color = parts[1]
    end
    if #parts >= 3 and parts[3] ~= "" then
        local symbol_full = parts[3]
        if trail_color and symbol_full:sub(1, #trail_color + 1) == trail_color .. "_" then
            trail_symbol = symbol_full:sub(#trail_color + 2)
        else
            trail_symbol = symbol_full
        end
    end
    return trail_color, trail_symbol
end

-- Scan relations to identify hiking routes
function relation_scan_function()
    local type = Find("type")
    local route = Find("route")

    -- Accept all hiking and foot routes
    if type == "route" and (route == "hiking" or route == "foot") then
        print("DEBUG: Found hiking route relation - " .. Find("name"))
        Accept()
    end
end

-- Process accepted relations and output their geometries
-- This is the CORRECT function for outputting relation geometries
function relation_function()
    local osmc = Find("osmc:symbol")
    local color = Find("color")
    local ref = Find("ref")
    local name = Find("name")
    local route = Find("route")
    local network = Find("network")

    print("DEBUG: Processing relation: " .. name .. " (osmc=" .. osmc .. ", color=" .. color .. ")")

    -- Output the relation geometry as a multilinestring
    Layer("hiking_routes", false)  -- false = linestring (not area)

    -- Basic attributes
    Attribute("class", "hiking_route")
    Attribute("route_type", route)

    if name ~= "" then
        Attribute("name", name)
    else
        Attribute("name", "Unnamed Route")
    end

    if ref ~= "" then Attribute("ref", ref) end
    if network ~= "" then Attribute("network", network) end
    if osmc ~= "" then Attribute("osmc_symbol", osmc) end
    if color ~= "" then Attribute("raw_color", color) end

    -- Parse OSMC symbol
    local t_color, t_symbol = parse_osmc(osmc)

    -- Fallback to color tag if OSMC didn't give a color
    if not t_color and color ~= "" then
        t_color = color
    end

    if t_color then
        Attribute("trail_color", t_color)
    else
        Attribute("trail_color", "unknown")
    end

    if t_symbol then
        Attribute("trail_symbol", t_symbol)
    else
        Attribute("trail_symbol", "none")
    end

    MinZoom(6)

    print("DEBUG: Output relation " .. name .. " to layer")
end

-- Don't process regular nodes
function node_function()
    -- Skip all nodes
end

-- Don't process regular ways (only relation geometries)
function way_function()
    -- Skip all ways - we only want relation geometries
end

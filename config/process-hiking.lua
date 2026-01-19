-- Tilemaker Lua config for Hungarian hiking maps

-- Define layers
node_keys = { "amenity", "shop", "tourism", "natural", "place", "man_made" }
way_keys = { "highway", "waterway", "natural", "landuse", "leisure", "boundary", "building" }

-- Initialize
function init_function()
end

-- Process nodes (points of interest)
function node_function(node)
    local amenity = node:Find("amenity")
    local tourism = node:Find("tourism")
    local natural = node:Find("natural")
    local place = node:Find("place")

    -- Hiking-relevant POIs
    if tourism == "alpine_hut" or tourism == "wilderness_hut" or
       amenity == "shelter" or tourism == "viewpoint" or
       amenity == "drinking_water" or natural == "spring" or
       natural == "peak" or natural == "saddle" or natural == "cave_entrance" then

        local layer = LayerAsCentroid("pois")
        layer:Attribute("type", tourism or amenity or natural)

        local name = node:Find("name")
        if name ~= "" then
            layer:Attribute("name", name)
        end

        local ele = node:Find("ele")
        if ele ~= "" then
            layer:AttributeNumeric("elevation", tonumber(ele))
        end
    end

    -- Place labels
    if place ~= "" then
        local layer = LayerAsCentroid("place_labels")
        layer:Attribute("type", place)
        layer:Attribute("name", node:Find("name"))

        local population = node:Find("population")
        if population ~= "" then
            layer:AttributeNumeric("population", tonumber(population))
        end
        layer:MinZoom(place == "city" and 6 or place == "town" and 8 or 10)
    end
end

-- Process ways (trails, roads, areas)
function way_function(way)
    local highway = way:Find("highway")
    local waterway = way:Find("waterway")
    local natural = way:Find("natural")
    local landuse = way:Find("landuse")
    local leisure = way:Find("leisure")
    local boundary = way:Find("boundary")
    local building = way:Find("building")

    -- Trails (most important for hiking maps)
    if highway == "path" or highway == "footway" or highway == "cycleway" or
       highway == "bridleway" or highway == "track" or highway == "steps" then

        local layer = Layer("trails", false)
        layer:Attribute("type", highway)

        local name = way:Find("name")
        if name ~= "" then
            layer:Attribute("name", name)
        end

        -- Trail markings and difficulty
        local sac_scale = way:Find("sac_scale")
        if sac_scale ~= "" then
            layer:Attribute("difficulty", sac_scale)
        end

        local trail_visibility = way:Find("trail_visibility")
        if trail_visibility ~= "" then
            layer:Attribute("visibility", trail_visibility)
        end

        -- Hungarian hiking trail colors (osmc:symbol, ref, color)
        local osmc = way:Find("osmc:symbol")
        if osmc ~= "" then
            layer:Attribute("osmc_symbol", osmc)
        end

        local ref = way:Find("ref")
        if ref ~= "" then
            layer:Attribute("ref", ref)
        end

        local color = way:Find("color")
        if color ~= "" then
            layer:Attribute("color", color)
        end

        -- Surface type
        local surface = way:Find("surface")
        if surface ~= "" then
            layer:Attribute("surface", surface)
        end

        layer:MinZoom(10)

    -- Roads (for context)
    elseif highway == "motorway" or highway == "trunk" or highway == "primary" or
           highway == "secondary" or highway == "tertiary" or highway == "unclassified" or
           highway == "residential" or highway == "service" then

        local layer = Layer("roads", false)
        layer:Attribute("type", highway)
        layer:Attribute("name", way:Find("name"))

        local surface = way:Find("surface")
        if surface ~= "" then
            layer:Attribute("surface", surface)
        end

        layer:MinZoom(highway == "motorway" and 8 or highway == "primary" and 9 or 10)
    end

    -- Waterways
    if waterway ~= "" then
        local layer = Layer("waterway", false)
        layer:Attribute("type", waterway)
        layer:Attribute("name", way:Find("name"))
        layer:MinZoom(waterway == "river" and 8 or 10)
    end

    -- Water bodies, forests, etc. (filled areas)
    if natural == "water" or landuse == "reservoir" then
        local layer = Layer("water", true)
        layer:Attribute("type", natural or landuse)
        layer:MinZoom(9)

    elseif natural == "wood" or landuse == "forest" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", "forest")
        layer:MinZoom(10)

    elseif landuse == "grass" or landuse == "meadow" or
           natural == "grassland" or leisure == "park" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", landuse or natural or leisure)
        layer:MinZoom(11)

    elseif landuse == "farmland" or landuse == "orchard" or landuse == "vineyard" then
        local layer = Layer("landuse", true)
        layer:Attribute("type", landuse)
        layer:MinZoom(11)
    end

    -- Buildings
    if building ~= "" then
        local layer = Layer("buildings", true)
        layer:MinZoom(13)
    end

    -- Boundaries (administrative)
    if boundary == "administrative" then
        local admin_level = tonumber(way:Find("admin_level"))
        if admin_level and admin_level <= 8 then
            local layer = Layer("boundaries", false)
            layer:AttributeNumeric("admin_level", admin_level)
            layer:MinZoom(admin_level <= 4 and 3 or admin_level <= 6 and 6 or 8)
        end
    end
end

-- Not processing multipolygon relations for simplicity
-- Add if needed for complex areas
function exit_function()
end

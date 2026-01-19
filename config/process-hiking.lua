-- Tilemaker Lua config for Hungarian hiking maps
-- Modern API (for Tilemaker 3.0+)

-- Define which keys we're interested in
node_keys = { "amenity", "shop", "tourism", "natural", "place", "man_made" }

-- Process nodes (points of interest)
function node_function()
    local amenity = Find("amenity")
    local tourism = Find("tourism")
    local natural = Find("natural")
    local place = Find("place")

    -- Hiking-relevant POIs
    if tourism == "alpine_hut" or tourism == "wilderness_hut" or
       amenity == "shelter" or tourism == "viewpoint" or
       amenity == "drinking_water" or natural == "spring" or
       natural == "peak" or natural == "saddle" or natural == "cave_entrance" then

        Layer("pois", false)
        Attribute("type", tourism or amenity or natural)

        local name = Find("name")
        if name ~= "" then
            Attribute("name", name)
        end

        local ele = Find("ele")
        if ele ~= "" then
            AttributeNumeric("elevation", tonumber(ele))
        end

        MinZoom(12)
    end

    -- Place labels
    if place ~= "" then
        Layer("place_labels", false)
        Attribute("type", place)

        local name = Find("name")
        if name ~= "" then
            Attribute("name", name)
        end

        local population = Find("population")
        if population ~= "" then
            AttributeNumeric("population", tonumber(population))
        end

        if place == "city" then
            MinZoom(6)
        elseif place == "town" then
            MinZoom(8)
        else
            MinZoom(10)
        end
    end
end

-- Process ways (trails, roads, areas)
function way_function()
    local highway = Find("highway")
    local waterway = Find("waterway")
    local natural = Find("natural")
    local landuse = Find("landuse")
    local leisure = Find("leisure")
    local boundary = Find("boundary")
    local building = Find("building")

    -- Trails (most important for hiking maps)
    if highway == "path" or highway == "footway" or highway == "cycleway" or
       highway == "bridleway" or highway == "track" or highway == "steps" then

        Layer("trails", false)
        Attribute("type", highway)

        local name = Find("name")
        if name ~= "" then
            Attribute("name", name)
        end

        -- Trail markings and difficulty
        local sac_scale = Find("sac_scale")
        if sac_scale ~= "" then
            Attribute("difficulty", sac_scale)
        end

        local trail_visibility = Find("trail_visibility")
        if trail_visibility ~= "" then
            Attribute("visibility", trail_visibility)
        end

        -- Hungarian hiking trail colors
        local osmc = Find("osmc:symbol")
        if osmc ~= "" then
            Attribute("osmc_symbol", osmc)
        end

        local ref = Find("ref")
        if ref ~= "" then
            Attribute("ref", ref)
        end

        local color = Find("color")
        if color ~= "" then
            Attribute("color", color)
        end

        -- Surface type
        local surface = Find("surface")
        if surface ~= "" then
            Attribute("surface", surface)
        end

        MinZoom(10)

    -- Roads (for context)
    elseif highway == "motorway" or highway == "trunk" or highway == "primary" or
           highway == "secondary" or highway == "tertiary" or highway == "unclassified" or
           highway == "residential" or highway == "service" or highway == "living_street" or
           highway == "road" or highway == "minor" then

        Layer("roads", false)
        Attribute("type", highway)

        local name = Find("name")
        if name ~= "" then
            Attribute("name", name)
        end

        local ref = Find("ref")
        if ref ~= "" then
            Attribute("ref", ref)
        end

        local surface = Find("surface")
        if surface ~= "" then
            Attribute("surface", surface)
        end

        if highway == "motorway" or highway == "trunk" then
            MinZoom(8)
        elseif highway == "primary" then
            MinZoom(9)
        elseif highway == "secondary" or highway == "tertiary" then
            MinZoom(10)
        else
            -- Residential and smaller roads appear from zoom 11
            MinZoom(11)
        end
    end

    -- Waterways
    if waterway ~= "" then
        Layer("waterway", false)
        Attribute("type", waterway)

        local name = Find("name")
        if name ~= "" then
            Attribute("name", name)
        end

        if waterway == "river" then
            MinZoom(8)
        else
            MinZoom(10)
        end
    end

    -- Water bodies (polygons)
    if natural == "water" or landuse == "reservoir" then
        Layer("water", true)
        Attribute("type", natural or landuse)
        MinZoom(9)
    end

    -- Forests (polygons)
    if natural == "wood" or landuse == "forest" then
        Layer("landuse", true)
        Attribute("type", "forest")
        MinZoom(10)
    end

    -- Grass/meadow (polygons)
    if landuse == "grass" or landuse == "meadow" or
       natural == "grassland" or leisure == "park" then
        Layer("landuse", true)
        Attribute("type", landuse or natural or leisure)
        MinZoom(11)
    end

    -- Farmland (polygons)
    if landuse == "farmland" or landuse == "orchard" or landuse == "vineyard" then
        Layer("landuse", true)
        Attribute("type", landuse)
        MinZoom(11)
    end

    -- Buildings (polygons)
    if building ~= "" then
        Layer("buildings", true)
        MinZoom(13)
    end

    -- Boundaries (administrative)
    if boundary == "administrative" then
        local admin_level = tonumber(Find("admin_level"))
        if admin_level and admin_level <= 8 then
            Layer("boundaries", false)
            AttributeNumeric("admin_level", admin_level)

            if admin_level <= 4 then
                MinZoom(3)
            elseif admin_level <= 6 then
                MinZoom(6)
            else
                MinZoom(8)
            end
        end
    end
end

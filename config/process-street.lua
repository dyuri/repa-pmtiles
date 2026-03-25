-- Tilemaker Lua config for Hungarian street/general maps
-- Modern API (for Tilemaker 3.0+)

-- Define which keys we're interested in
node_keys = { "place" }

-- Process nodes (place labels)
function node_function()
    local place = Find("place")

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
            MinZoom(9)
        else
            MinZoom(12)
        end
    end
end

-- Process ways (roads, areas)
function way_function()
    local highway = Find("highway")
    local waterway = Find("waterway")
    local natural = Find("natural")
    local landuse = Find("landuse")
    local leisure = Find("leisure")
    local boundary = Find("boundary")
    local building = Find("building")

    -- Roads
    if highway == "motorway" or highway == "trunk" or highway == "primary" or
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
            MinZoom(6)
        elseif highway == "primary" then
            MinZoom(9)
        elseif highway == "secondary" or highway == "tertiary" then
            MinZoom(11)
        else
            MinZoom(13)
        end
    end

    -- Footways/paths (minimal, for context at high zoom)
    if highway == "footway" or highway == "path" or highway == "steps" or
       highway == "pedestrian" then
        Layer("roads", false)
        Attribute("type", highway)
        MinZoom(14)
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
            MinZoom(9)
        end
    end

    -- Water bodies (polygons)
    if natural == "water" or landuse == "reservoir" then
        Layer("water", true)
        Attribute("type", natural or landuse)
        MinZoom(8)
    end

    -- Forests (polygons)
    if natural == "wood" or landuse == "forest" then
        Layer("landuse", true)
        Attribute("type", "forest")
        MinZoom(8)
    end

    -- Grass/meadow/parks (polygons)
    if landuse == "grass" or landuse == "meadow" or
       natural == "grassland" or leisure == "park" then
        Layer("landuse", true)
        Attribute("type", landuse or natural or leisure)
        MinZoom(9)
    end

    -- Farmland (polygons)
    if landuse == "farmland" or landuse == "orchard" or landuse == "vineyard" then
        Layer("landuse", true)
        Attribute("type", landuse)
        MinZoom(9)
    end

    -- Industrial/commercial (polygons)
    if landuse == "industrial" or landuse == "commercial" or landuse == "retail" then
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

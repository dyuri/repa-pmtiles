-- Tilemaker Lua config for Hungarian bike maps
-- Modern API (for Tilemaker 3.0+)

node_keys = { "amenity", "shop", "tourism", "natural", "place", "man_made" }

-- Accept bicycle and MTB route relations only
function relation_scan_function()
    local type = Find("type")
    local route = Find("route")
    if type == "route" then
        if route == "bicycle" or route == "mtb" then
            Accept()
        end
    end
end

-- Emit route relation geometries to cycling_routes layer
function relation_function()
    local success, err = pcall(function()
        local route   = Find("route")
        local network = Find("network")
        local ref     = Find("ref")
        local name    = Find("name")
        local colour  = Find("colour")
        local color   = Find("color")

        Layer("cycling_routes", false)
        Attribute("route", route)
        if network ~= "" then Attribute("network", network) end
        if ref     ~= "" then Attribute("ref", ref) end
        if name    ~= "" then Attribute("name", name) end

        local route_colour = colour ~= "" and colour or (color ~= "" and color or nil)
        if route_colour then Attribute("colour", route_colour) end

        if network == "icn" then
            MinZoom(4)
        elseif network == "ncn" then
            MinZoom(6)
        elseif network == "rcn" then
            MinZoom(8)
        else
            MinZoom(10)
        end
    end)
end

-- Process nodes (bike-relevant POIs + place labels)
function node_function()
    local amenity = Find("amenity")
    local place   = Find("place")

    if amenity == "bicycle_repair_station" or amenity == "bicycle_rental" or
       amenity == "bicycle_parking"        or amenity == "drinking_water" then
        Layer("pois", false)
        Attribute("type", amenity)
        local name = Find("name")
        if name ~= "" then Attribute("name", name) end
        MinZoom(12)
    end

    if place ~= "" then
        Layer("place_labels", false)
        Attribute("type", place)
        local name = Find("name")
        if name ~= "" then Attribute("name", name) end
        local population = Find("population")
        if population ~= "" then AttributeNumeric("population", tonumber(population)) end
        if place == "city" then MinZoom(6)
        elseif place == "town" then MinZoom(9)
        else MinZoom(12) end
    end
end

-- Process ways (cycling infrastructure, roads, landuse, water, etc.)
function way_function()
    local highway  = Find("highway")
    local waterway = Find("waterway")
    local natural  = Find("natural")
    local landuse  = Find("landuse")
    local leisure  = Find("leisure")
    local boundary = Find("boundary")
    local building = Find("building")
    local bicycle  = Find("bicycle")
    local mtb_scale = Find("mtb:scale")

    -- Dedicated cycling infrastructure (cycling layer)
    local is_cycleway  = highway == "cycleway"
    local is_mtb_trail = mtb_scale ~= ""
    local is_mtb_path  = (highway == "path" or highway == "track") and
                         (bicycle == "designated" or bicycle == "yes")

    if is_cycleway or is_mtb_trail or is_mtb_path then
        Layer("cycling", false)

        local ctype
        if is_cycleway then
            ctype = "cycleway"
        elseif is_mtb_trail then
            ctype = "mtb_trail"
            Attribute("mtb_scale", mtb_scale)
        else
            ctype = "mtb_path"
        end
        Attribute("type", ctype)
        Attribute("highway", highway)

        local surface = Find("surface")
        if surface ~= "" then Attribute("surface", surface) end

        local name = Find("name")
        if name ~= "" then Attribute("name", name) end

        local oneway_bicycle = Find("oneway:bicycle")
        if oneway_bicycle ~= "" then Attribute("oneway_bicycle", oneway_bicycle) end

        if is_cycleway then
            MinZoom(11)
        else
            MinZoom(12)
        end

    -- Road network (context + bike access metadata)
    elseif highway == "motorway"    or highway == "trunk"        or highway == "primary"   or
           highway == "secondary"   or highway == "tertiary"     or highway == "unclassified" or
           highway == "residential" or highway == "service"      or highway == "living_street" or
           highway == "road"        or highway == "minor" then

        Layer("roads", false)
        Attribute("type", highway)

        local name = Find("name")
        if name ~= "" then Attribute("name", name) end

        local ref = Find("ref")
        if ref ~= "" then Attribute("ref", ref) end

        local surface = Find("surface")
        if surface ~= "" then Attribute("surface", surface) end

        if bicycle ~= "" then Attribute("bicycle", bicycle) end

        local cycleway       = Find("cycleway")
        local cycleway_left  = Find("cycleway:left")
        local cycleway_right = Find("cycleway:right")
        if cycleway       ~= "" then Attribute("cycleway",       cycleway) end
        if cycleway_left  ~= "" then Attribute("cycleway_left",  cycleway_left) end
        if cycleway_right ~= "" then Attribute("cycleway_right", cycleway_right) end

        if bicycle == "no" then Attribute("bike_forbidden", "yes") end

        if highway == "motorway" or highway == "trunk" then MinZoom(8)
        elseif highway == "primary" then MinZoom(10)
        elseif highway == "secondary" or highway == "tertiary" then MinZoom(12)
        else MinZoom(13) end
    end

    -- Waterways
    if waterway ~= "" then
        Layer("waterway", false)
        Attribute("type", waterway)
        local name = Find("name")
        if name ~= "" then Attribute("name", name) end
        if waterway == "river" then MinZoom(8) else MinZoom(9) end
    end

    -- Water bodies
    if natural == "water" or landuse == "reservoir" then
        Layer("water", true)
        Attribute("type", natural ~= "" and natural or landuse)
        MinZoom(8)
    end

    -- Forests
    if natural == "wood" or landuse == "forest" then
        Layer("landuse", true)
        Attribute("type", "forest")
        MinZoom(8)
    end

    -- Grass / meadow / park
    if landuse == "grass" or landuse == "meadow" or
       natural == "grassland" or leisure == "park" then
        Layer("landuse", true)
        Attribute("type", landuse ~= "" and landuse or (natural ~= "" and natural or leisure))
        MinZoom(9)
    end

    -- Farmland
    if landuse == "farmland" or landuse == "orchard" or landuse == "vineyard" then
        Layer("landuse", true)
        Attribute("type", landuse)
        MinZoom(9)
    end

    -- Buildings
    if building ~= "" then
        Layer("buildings", true)
        MinZoom(13)
    end

    -- Administrative boundaries
    if boundary == "administrative" then
        local admin_level = tonumber(Find("admin_level"))
        if admin_level and admin_level <= 8 then
            Layer("boundaries", false)
            AttributeNumeric("admin_level", admin_level)
            if admin_level <= 4 then MinZoom(3)
            elseif admin_level <= 6 then MinZoom(6)
            else MinZoom(8) end
        end
    end
end

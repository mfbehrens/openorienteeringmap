-- Set this to the projection you want to use
local srid = 3857

-- Helper function that looks at the tags and decides if this is possibly
-- an area.
local function has_area_tags(tags)
    if tags.area == 'yes' then
        return true
    end
    if tags.area == 'no' then
        return false
    end

    return tags.aeroway
        or tags.amenity
        or tags.building
        or tags.harbour
        or tags.historic
        or tags.landuse
        or tags.leisure
        or tags.man_made
        or tags.military
        or tags.natural
        or tags.office
        or tags.place
        or tags.power
        or tags.public_transport
        or tags.shop
        or tags.sport
        or tags.tourism
        or tags.water
        or tags.waterway
        or tags.wetland
        or tags['abandoned:aeroway']
        or tags['abandoned:amenity']
        or tags['abandoned:building']
        or tags['abandoned:landuse']
        or tags['abandoned:power']
        or tags['area:highway']
        or tags['building:part']
end

local function length_in_m(length)
    if not length then
        return nil
    end

    local len_str = tostring(length):lower():gsub(",", ".")
    local num = len_str:match("(%d+%.?%d*)")  -- Extract the numeric part
    if not num then
        return nil
    end
    num = tonumber(num)  -- Convert the numeric part to a number

    -- Check for the unit in a single pass
    if len_str:find("km") then
        return num * 1000
    elseif len_str:find("mi") then
        return num * 1609.34
    elseif len_str:find("ft") then
        return num * 0.3048
    elseif len_str:find("in") then
        return num * 0.0254
    else
        -- Assume meters if no unit is found
        return num
    end
end

local tab_topo_point = osm2pgsql.define_node_table('topo_point', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'point', projection = srid, not_null = true}
})

local tab_topo_line = osm2pgsql.define_way_table('topo_line', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_landcover = osm2pgsql.define_area_table('landcover', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    -- { column = 'difficulty', type = 'smallint' },
    { column = 'geom', type = 'multipolygon', projection = srid, not_null = true },
})

local tab_waterways = osm2pgsql.define_way_table('waterways', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_water = osm2pgsql.define_area_table('water', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'multipolygon', projection = srid, not_null = true },
})

local tab_pathways = osm2pgsql.define_way_table('pathways', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_path_area = osm2pgsql.define_area_table('path_area', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'multipolygon', projection = srid, not_null = true },
})

local tab_landmark_point = osm2pgsql.define_node_table('landmark_point', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text' },
    { column = 'geom', type = 'point', projection = srid, not_null = true },
})

local tab_landmark_line = osm2pgsql.define_way_table('landmark_line', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_barrier_point = osm2pgsql.define_node_table('barrier_point', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text' },
    { column = 'geom', type = 'point', projection = srid, not_null = true },
})

local tab_barrier_line = osm2pgsql.define_way_table('barrier_line', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_building = osm2pgsql.define_area_table('building', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'polygon', projection = srid, not_null = true },
})

local tab_out_of_bounds = osm2pgsql.define_area_table('out_of_bounds', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'polygon', projection = srid, not_null = true },
})

local barrier_map = {
    gate                        = 'opening',
    entrance                    = 'opening',
    ["full-height_turnstile"]   = 'opening',
    hampshire_gate              = 'opening',
    kissing_gate                = 'opening',
    bollard         = 'bollard',
    lift_gate       = 'boom',
    swing_gate      = 'boom',
}


function osm2pgsql.process_node(object)
    --  Uncomment next line to look at the object data:
    --  print(inspect(object))

    local tags = object.tags

    -- Power features (13% of all tagged nodes)
    if tags.power then
        if tags.power == 'tower' then
            tab_landmark_point:insert({
                type = 'power_tower',
                geom = object:as_point(),
            })
        elseif tags.power == 'pole' then
            tab_landmark_point:insert({
                type = 'power_pole',
                geom = object:as_point(),
            })
        end


    -- Natural features (11%)
    elseif tags.natural == 'tree' then
        -- shortcut - other natural points below
        tab_landmark_point:insert({
            type = 'tree',
            geom = object:as_point(),
        })


    -- Highway features (7%)
    elseif tags.highway then
        -- highway=crossing (4%)
        if tags.highway == 'crossing' then
            -- shortcut
        elseif tags.highway == 'street_lamp' then
            tab_landmark_point:insert({
                type = 'street_lamp',
                geom = object:as_point(),
            })
        elseif tags.highway == 'ford' then
            -- no symbol but would be nice
        elseif tags.highway == 'traffic_mirror' then
        elseif tags.highway == 'turning_circle' then
            -- local diameter = tags.diameter
            -- tab_path_area:insert({
            --     type = 'turning_circle',
            --     geom = object:,
            -- })
        end


    -- Barrier features (3%)
    elseif tags.barrier then
        local map_result = barrier_map[tags['barrier']]
        if map_result then
            tab_barrier_point:insert({
                type = map_result,
                geom = object:as_point(),
            })
        end


    -- natural
    elseif tags.natural then
        if tags.natural == 'geyser' then
            tab_landmark_point:insert({
                type = "fountain",
                geom = object:as_point(),
            })
        elseif tags.natural == 'hot_spring' or tags.natural == 'spring' then
            tab_landmark_point:insert({
                type = "spring",
                geom = object:as_point(),
            })
        elseif tags.natural == 'cave_entrance' then
            tab_landmark_point:insert({
                type = "cave",
                geom = object:as_point(),
            })
        elseif tags.natural == 'fumarole' then
            tab_landmark_point:insert({
                type = "round",
                geom = object:as_point(),
            })
        elseif tags.natural == 'hill' then
            tab_topo_point:insert({
                type = "knoll",
                geom = object:as_point(),
            })
        elseif tags.natural == 'rock' or tags.natural == 'stone' then
            tab_topo_point:insert({
                type = "rock",
                geom = object:as_point(),
            })
        end


    -- Amenities
    elseif tags.amenity then
        if tags.amenity == 'bbq' then
            tab_landmark_point:insert({
                type = "firepit",
                geom = object:as_point(),
            })
        elseif tags.amenity == "bench" then
            tab_landmark_point:insert({
                type = "bench",
                geom = object:as_point(),
            })
        elseif tags.amenity == "drinking_water" then
            tab_landmark_point:insert({
                type = "drinking_water",
                geom = object:as_point(),
            })
        elseif tags.amenity == "kneipp_water_cure" then
            tab_landmark_point:insert({
                type = "water_feature",
                geom = object:as_point(),
            })
        elseif tags.amenity == "hunting_stand" then
            tab_landmark_point:insert({
                type = "hunting_stand",
                geom = object:as_point(),
            })
        elseif tags.amenity == 'post_box' then
            tab_landmark_point:insert({
                type = "post_box",
                geom = object:as_point(),
            })
        elseif tags.amenity == 'waste_basket' then
            tab_landmark_point:insert({
                type = "waste_basket",
                geom = object:as_point(),
            })
        end


    -- Manmade
    elseif tags.man_made then
        if tags.man_made == 'adit' or tags.man_made == 'cellar_entrance' then
            tab_topo_point:insert({
                type = "cave",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'antenna' or tags.man_made == 'mast' or tags.man_made == 'chimney' or tags.man_made == 'communications_tower' or tags.man_made == 'tower' then
            if tags.height then
                local height = length_in_m(tags.height)
                if height and height < 20 then
                    tab_landmark_point:insert({
                        type = "small_tower",
                        geom = object:as_point(),
                    })
                else
                    tab_landmark_point:insert({
                        type = "high_tower",
                        geom = object:as_point(),
                    })
                end
            else
                tab_landmark_point:insert({
                    type = "high_tower",
                    geom = object:as_point(),
                })
            end

        elseif tags.man_made == 'beacon' then
            tab_landmark_point:insert({
                type = "high_tower",
                geom = object:as_point(),
            })

        elseif tags.man_made == 'cairn' then
            tab_landmark_point:insert({
                type = "cairn",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'cross' then
            tab_landmark_point:insert({
                type = "cross",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'flagpole' then
            tab_landmark_point:insert({
                type = "small_tower",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'lighthouse' then
            tab_landmark_point:insert({
                type = "high_tower",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'utility_pole' then
            tab_landmark_point:insert({
                type = "small_tower",
                geom = object:as_point(),
            })

        elseif tags.man_made == 'water_tap' or tags.man_made == 'water_well' then
            tab_landmark_point:insert({
                type = "water_feature",
                geom = object:as_point(),
            })
        elseif tags.man_made == 'water_tower' then
            tab_landmark_point:insert({
                type = "high_tower",
                geom = object:as_point(),
            })
        end
    end
end

local natural_map = {
    bare_rock = 'bare_rock',
    beach =  nil,
    fell = 'tundra',
    glacier = 'glacier',
    grassland = 'grassland',
    heath = 'heath',
    mud = 'marsh',
    sand = 'sand',
    scree = 'scree',
    scrub = 'scrub',
    shingle = 'gravel',
    shrubbery =  nil,
    tundra = 'tundra',
    water =  nil,
    wetland = 'marsh',
    wood = 'forest',
}

local landuse_map = {
    allotments = 'garden',
    animal_keeping = 'farmland',
    farmland = 'farmland',
    flowerbed = 'impassable_scrub',
    forest = 'forest',
    grass = 'grass',
    greenfield = 'grass',
    logging = 'open',
    meadow = 'grassland',
    orchard = 'orchard',
    vineyard = 'orchad',
}

local leisure_map = {
    garden = 'garden',
    park = 'park',
    pitch = 'pitch',
    swimming_pool = 'water',
    track = 'open',
}

local waterway_map = {
    canal = 'river',
    drain = 'stream',
    ditch = 'stream',
    river = 'river',
    stream = 'stream',
}

local highway_map = {
    motorway = 'impassable_road',
    trunk = 'impassable_road',
    primary = 'high_traffic_road',
    secondary = 'high_traffic_road',
    tertiary = 'high_traffic_road',
    unclassified = 'wide_road',
    road = 'wide_road',
    residential = 'wide_road',
    motorway_link = 'high_traffic_road',
    trunk_link = 'high_traffic_road',
    primary_link = 'high_traffic_road',
    secondary_link = 'high_traffic_road',
    tertiary_link = 'high_traffic_road',
    living_street = 'wide_road',
    service = 'wide_road',
    pedestrian = 'wide_road',
    escape = 'impassable_road',
    raceway = 'impassable_road',
    busway = 'high_traffic_road',
    track = 'track',
    path = 'footpath',
    footway = 'footpath',
    bridleway = 'footpath',
    steps = 'steps',
    sidewalk = 'footpath',
}

local surface_map = {
    paved = 'paved',
    asphalt = 'paved',
    chipseal = 'paved',
    concrete = 'paved',
    ['concrete:lanes'] = 'paved',
    ['concrete:plates'] = 'paved',
    paving_stones = 'paved',
    ['paving_stones:lanes'] = 'paved',
    grass_paver = 'paved',
    sett = 'paved',
    unhewn_cobblestone = 'hard',
    cobblestone = 'paved',
    bricks = 'paved',
    metal = 'paved',
    metal_grid = 'paved',
    wood = 'paved',
    stepping_stones = 'hard',
    rubber = 'paved',
    tiles = 'paved',
    unpaved = 'unpaved',
    compacted = 'hard',
    fine_gravel = 'unpaved',
    gravel = 'unpaved',
    shells = 'unpaved',
    rock = 'hard',
    pebblestone = 'unpaved',
    ground = 'unpaved',
    dirt = 'unpaved',
    earth = 'unpaved',
    mud = 'slow',
    sand = 'slow',
    woodchips = 'unpaved',
    snow = 'unpaved',
    ice = 'unpaved',
    salt = 'unpaved',
    clay = 'hard',
    tartan = 'paved',
    artificial_turf = 'unpaved',
    acrylic = 'paved',
    carpet = 'paved',
    plastic = 'paved',
}

local visibility_map = {
    excellent = 5,
    good = 4,
    intermediate = 3,
    bad = 2,
    horrible = 1,
    no = 0,
}

local tracktype_map = {
    grade1 = 1,
    grade2 = 2,
    grade3 = 3,
    grade4 = 4,
    grade5 = 5,
}

function insert_polygon(tab, object, type)
    tab:insert({
        type = type,
        geom = object:as_polygon()
    })
end

function osm2pgsql.process_way(object)
    --  Uncomment next line to look at the object data:
    --  print(inspect(object))

    local tags = object.tags
    local barrier = true -- object can still be a barrier

    -- building=yes (50%)
    if tags.building == 'yes' then
        insert_polygon(tab_building, object, 'building')

    elseif object.is_closed and has_area_tags(tags) then
        -- areas
        if tags.building then
            -- rest of the buildings
            local building_type = "building"
            if tags.building == 'roof' then
                building_type = 'canopy'
            elseif tags.building == 'ruins' then
                building_type = 'ruin'
            end

            insert_polygon(tab_building, object, building_type)
            barrier = false
        end

        if tags.natural then
            local map_result = natural_map[tags.natural]
            if map_result then
                insert_polygon(tab_landcover, object, map_result)
            else
                if tags.natural == 'water' then
                    -- leave map_result = nil
                    insert_polygon(tab_water, object, tags.waterway)
                elseif tags.natural == 'beach' then
                    if tags.surface == 'gravel' then
                        map_result = "gravel"
                    else
                        map_result = "sand"
                    end
                elseif tags.natural == 'shrubbery' then
                    if tags['shrubbery:density'] == 'medium' or tags['shrubbery:density'] == 'dense' then
                        map_result = "impassable_scrub"
                    else
                        map_result = "scrub"
                    end
                -- elseif tags.natural == 'wetland' then
                --     map_result = wetland"
                end
                if map_result then
                    insert_polygon(tab_landcover, object, map_result)
                end
            end

        elseif tags.landuse then
            local map_result = landuse_map[tags.landuse]
            if map_result then
                insert_polygon(tab_landcover, object, map_result)
            end

        elseif tags.leisure then
            local map_result = leisure_map[tags.leisure]
            if map_result then
                insert_polygon(tab_landcover, object, map_result)
            end

        elseif tags.highway or tags['area:highway'] then
            local map_result = highway_map[tags.highway or tags['area:highway']]
            if map_result then
                insert_polygon(tab_path_area, object, map_result)
                barrier = false
            end
        end

    end

    -- ways
    -- highway
    if tags.highway then
        local map_result = highway_map[tags.highway]
        if map_result == 'footpath' then
            local width = length_in_m(tags.width)
            local surface = surface_map[tags.surface] or 'unpaved'
            local visibility = visibility_map[tags.trail_visibility]

            if surface and surface == 'paved' then
                if width and width > 2.5 and (not visibility or visibility and visibility > 3) then
                    map_result = 'road'
                else
                    map_result = 'footpath'
                end

            elseif visibility and visibility >= 4 then
                map_result = 'footpath'

            elseif visibility and visibility <= 1 then
                map_result = 'less_distinct_small_footpath'

            else
                map_result = 'small_footpath'
            end

        elseif map_result == 'track' then
            local surface = surface_map[tags.surface]
            local tracktype = tracktype_map[tags.tracktype]

            -- If tracktype is 1 or if tracktype is not set if surface is paved
            if tracktype and tracktype == 1 or not tracktype and surface and surface == 'paved' then
                map_result = 'road'
            else
                map_result = 'track'
            end
        end
        if map_result then
            tab_pathways:insert({
                type = map_result,
                geom = object:as_linestring()
            })
            barrier = false
        end

    elseif tags.railway then
        if tags.railway == 'rail' then
            tab_pathways:insert({
                type = 'rail',
                geom = object:as_linestring()
            })
        else
            tab_pathways:insert({
                type = 'light_rail',
                geom = object:as_linestring()
            })
        end

    -- waterways
    elseif tags.waterway then
        local map_result = waterway_map[tags.waterway]
        if map_result then
            tab_waterways:insert({
                type = map_result,
                geom = object:as_linestring()
            })
        end

    -- power
    elseif tags.power then
        if tags.power == 'line' then
            tab_landmark_line:insert({
                type = "major_power_line",
                geom = object:as_linestring()
            })
        elseif tags.power == 'minor_line' then
            tab_landmark_line:insert({
                type = "power_line",
                geom = object:as_linestring()
            })
        end

    -- aerialway
    elseif tags.aerialway then
        -- TODO specify more
        tab_landmark_line:insert({
            type = "aerialway",
            geom = object:as_linestring()
        })
    end

    -- break when barrier was set to false before
    if not barrier then
        return
    end

    if tags.barrier or tags['disused:barrier'] then
        -- handle barriers sperately since most features can be surrounded by a fence
        local barrier_type = nil
        if tags.barrier == 'fence' or tags.barrier == 'yes' then
            barrier_type = "impassable_fence"
        elseif tags.barrier == 'chain' then
            barrier_type = "fence"
        elseif tags.barrier == 'wall' or tags.barrier == 'city_wall' or tags.barrier == 'retaining_wall' then
            barrier_type = "impassable_wall"
        elseif tags.barrier == 'hedge' then
            barrier_type = "hedge"
        elseif tags['disused:barrier'] == 'fence' then
            barrier_type = "ruined_fence"
        elseif tags['disused:barrier'] == 'wall' then
            barrier_type = "ruined_wall"
        end

        if barrier_type then
            tab_barrier_line:insert({
                type = barrier_type,
                geom = object:as_linestring(),
            })
        end
    end
end

local function insert_multipolygon(tab, object, type)
    for g in object:as_multipolygon():geometries() do
        tab:insert({
            type = type,
            geom = g,
        })
    end
end

function osm2pgsql.process_relation(object)

    local tags = object.tags
    local barrier = true -- object can still be a barrier


    if tags.type == 'multipolygon' then

        -- building=yes (50%)
        if tags.building == 'yes' then
            insert_multipolygon(tab_building, object, 'building')

        elseif has_area_tags(tags) then
            -- areas
            if tags.building then
                -- rest of the buildings
                local building_type = "building"
                if tags.building == 'roof' then
                    building_type = 'canopy'
                elseif tags.building == 'ruins' then
                    building_type = 'ruin'
                end

                insert_multipolygon(tab_building, object, building_type)
                barrier = false
            end

            if tags.natural then
                local map_result = natural_map[tags.natural]
                if map_result then
                    insert_multipolygon(tab_landcover, object, map_result)
                else
                    if tags.natural == 'water' then
                        -- leave map_result = nil
                        insert_multipolygon(tab_water, object, tags.waterway)
                    elseif tags.natural == 'beach' then
                        if tags.surface == 'gravel' then
                            map_result = "gravel"
                        else
                            map_result = "sand"
                        end
                    elseif tags.natural == 'shrubbery' then
                        if tags['shrubbery:density'] == 'medium' or tags['shrubbery:density'] == 'dense' then
                            map_result = "impassable_scrub"
                        else
                            map_result = "scrub"
                        end
                    -- elseif tags.natural == 'wetland' then
                    --     map_result = wetland"
                    end
                    if map_result then
                        insert_multipolygon(tab_landcover, object, map_result)
                    end
                end

            elseif tags.landuse then
                local map_result = landuse_map[tags.landuse]
                if map_result then
                    insert_multipolygon(tab_landcover, object, map_result)
                end

            elseif tags.leisure then
                local map_result = leisure_map[tags.leisure]
                if map_result then
                    insert_multipolygon(tab_landcover, object, map_result)
                end

            elseif tags.highway or tags['area:highway'] then
                local map_result = highway_map[tags.highway or tags['area:highway']]
                if map_result then
                    insert_multipolygon(tab_path_area, object, map_result)
                    barrier = false
                end
            end
        end

        -- break when barrier was set to false before
        if not barrier then
            return
        end

        if tags.barrier or tags['disused:barrier'] then
            -- handle barriers sperately since most features can be surrounded by a fence
            local barrier_type = nil
            if tags.barrier == 'fence' or tags.barrier == 'yes' then
                barrier_type = "impassable_fence"
            elseif tags.barrier == 'chain' then
                barrier_type = "fence"
            elseif tags.barrier == 'wall' or tags.barrier == 'city_wall' or tags.barrier == 'retaining_wall' then
                barrier_type = "impassable_wall"
            elseif tags.barrier == 'hedge' then
                barrier_type = "hedge"
            elseif tags['disused:barrier'] == 'fence' then
                barrier_type = "ruined_fence"
            elseif tags['disused:barrier'] == 'wall' then
                barrier_type = "ruined_wall"
            end
    
            if barrier_type then
                for g in object:as_multilinestring():geometries() do
                    tab_barrier_line:insert({
                        type = barrier_type,
                        geom = g,
                    })
                end
            end
        end
    end
end

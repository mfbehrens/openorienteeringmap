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
    { column = 'geom', type = 'polygon', projection = srid, not_null = true },
})

local tab_waterways = osm2pgsql.define_way_table('waterways', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_water_polygon = osm2pgsql.define_area_table('water_polygon', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'polygon', projection = srid, not_null = true },
})

local tab_pathways = osm2pgsql.define_way_table('pathways', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'linestring', projection = srid, not_null = true}
})

local tab_path_polygon = osm2pgsql.define_area_table('path_polygon', {
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'type', type = 'text', not_null = true },
    { column = 'geom', type = 'polygon', projection = srid, not_null = true },
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

    if tags['power'] then
        if tags['power'] == 'tower' then
            tab_landmark_point:insert({
                type = 'power_tower',
                geom = object:as_point()
            })
        elseif tags['power'] == 'pole' then
            tab_landmark_point:insert({
                type = 'power_pole',
                geom = object:as_point()
            })
        end


    -- Natural features (11%)

    elseif tags['natural'] == 'tree' then
        tab_landmark_point:insert({
            type = 'tree',
            geom = object:as_point()
        })


    -- Highway features (7%)
    elseif tags['highway'] then
        -- highway=crossing (4%)
        if tags['highway'] == 'crossing' then
        elseif tags['highway'] == 'street_lamp' then
            tab_landmark_point:insert({
                type = 'street_lamp',
                geom = object:as_point()
            })
        end

    
    -- Barrier features (3%)
    elseif tags['barrier'] then
        t = barrier_map[tags['barrier']]
        if t then
            tab_barrier_point:insert({
                type = t,
                geom = object:as_point()
            })
        end
    end
end

function osm2pgsql.process_way(object)
    --  Uncomment next line to look at the object data:
    --  print(inspect(object))

    local tags = object.tags

    if object.is_closed and has_area_tags(object) then
        -- areas
        if tags['building'] then
            -- building=yes (50%)
            if tags['building'] == 'yes' then
                tab_building:insert({
                    type = 'building',
                    geom = object:as_polygon()
                })
            elseif tags['building'] == 'roof' then
                tab_building:insert({
                    type = 'canopy',
                    geom = object:as_polygon()
                })
            elseif tags['building'] == 'ruins' then
                tab_building:insert({
                    type = 'ruins',
                    geom = object:as_polygon()
                })
            else
                tab_building:insert({
                    type = 'building',
                    geom = object:as_polygon()
                })
            end
        end
    else
        -- ways
        -- highway
        if tags['highway'] then
            tab_pathways:insert({
                type = tags['highway'],
                geom = object:as_linestring()
            })
        end
    end
end

function osm2pgsql.process_relation(object)
    -- local tags = object.tags
    -- if tags.type == 'multipolygon' and tags.building then
    --     -- From the relation we get multipolygons...
    --     local mp = object:as_multipolygon()
    --     -- ...and split them into polygons which we insert into the table
    --     for geom in mp:geometries() do
    --         buildings:insert({
    --             geom = geom
    --         })
    --     end
    -- end
end


local streets = osm2pgsql.define_way_table('streets', {
    { column = 'type',    type = 'text' },
    { column = 'name',    type = 'text' },
    { column = 'name_fr', type = 'text' },
    { column = 'name_nl', type = 'text' },
    { column = 'tags',    type = 'jsonb' },
    { column = 'geom',    type = 'linestring' },
})

local parks = osm2pgsql.define_area_table('parks', {
    -- Define an autoincrementing id column, QGIS likes a unique id on the table
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'geom', type = 'polygon' },
    { column = 'name',    type = 'text' },
})

-- local land = osm2pgsql.define_area_table('land', {
--     -- Define an autoincrementing id column, QGIS likes a unique id on the table
--     { column = 'id', sql_type = 'serial', create_only = true },
--     { column = 'geom', type = 'polygon' },
-- })

local water = osm2pgsql.define_area_table('water', {
    -- Define an autoincrementing id column, QGIS likes a unique id on the table
    { column = 'id', sql_type = 'serial', create_only = true },
    { column = 'geom', type = 'polygon' },
})

local coastlines = osm2pgsql.define_way_table('coastlines', {
    { column = 'geom', type = 'linestring', projection = 3031 },
})



local get_highway_value = osm2pgsql.make_check_values_func({
    'motorway', 'trunk', 'primary', 'secondary', 'tertiary',
    'motorway_link', 'trunk_link', 'primary_link', 'secondary_link', 'tertiary_link',
    'unclassified', 'residential', 'pedestrian'
})

local get_landuse = osm2pgsql.make_check_values_func({
    'retail', 'residential'
})

local get_natural_water = osm2pgsql.make_check_values_func({
    -- 'bay', 'reef', 'strait', 'bare_rock', 'coastline'
})


function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' and object.tags.leisure then
        parks:add_row({
            -- The 'split_at' setting tells osm2pgsql to split up MultiPolygons
            -- into several Polygon geometries.
            name    = object.tags.name,
            geom = { create = 'area', split_at = 'multi' }
        })
    end
    if object.tags.type == 'multipolygon' and (object.tags.water or object.tags.waterway or get_natural_water(object.tags.natural)) then
        water:add_row({
            -- The 'split_at' setting tells osm2pgsql to split up MultiPolygons
            -- into several Polygon geometries.
            geom = { create = 'area', split_at = 'multi' }
        })
    end
    -- if object.tags.type == 'multipolygon' and get_landuse(object.tags.landuse) then
    --     land:add_row({
    --         -- The 'split_at' setting tells osm2pgsql to split up MultiPolygons
    --         -- into several Polygon geometries.
    --         geom = { create = 'area', split_at = 'multi' }
    --     })
    -- end
end


function osm2pgsql.process_way(object)

    if object.tags.natural == 'coastline' then
        coastlines:add_row({})
    end

    -- if object.is_closed and get_landuse(object.tags.landuse) then
    --     land:add_row({
    --         geom = { create = 'area' }
    --     })
    -- end

    if object.is_closed and object.tags.leisure then
        parks:add_row({
            name    = object.tags.name,
            geom = { create = 'area' }
        })
    end

    if object.is_closed and (object.tags.water or object.tags.waterway or get_natural_water(object.tags.natural)) then
        water:add_row({
            geom = { create = 'area' }
        })
    end
    
    local highway_type = get_highway_value(object.tags.highway)

    if not highway_type then
        return
    end

    if object.tags.area == 'yes' then
        return
    end

    streets:add_row({
        type    = highway_type,
        tags    = object.tags,
        name    = object.tags.name,
        name_fr = object.tags['name:fr'],
        name_nl = object.tags['name:nl'],
        geom    = { create = 'line' }
    })
end


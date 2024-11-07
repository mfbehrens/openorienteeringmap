# OpenOrienteeringMap

*Orienteering Maps from [OpenStreetMap](https://openstreetmap.org/) data*

## Usage
- `podman-compose up postgis`
- Wait for the postgis setup to finish
- `podman-compose up osm2pgsql`
- Wait for the import to finish
- `podman-compose up martin`
- Check if server is working

## Tech stack

- TODO pyosmium-up-to-date (Update mapdata)
- osm2pgsql (convert osm to postgis)
- martin (on the fly vector tiles renderer)
- maputnik (style editing)
- Maplibre GL (rendering)

## Data sources
- Main source: [Geofabrik](https://download.geofabrik.de/)
- Coastline: [osmdata.openstreetmap.de](https://osmdata.openstreetmap.de/data/water-polygons.html)
- DEM: ?

## Creating Water Geometry

- Download the [WGS84 water tiles](https://osmdata.openstreetmap.de/download/water-polygons-split-4326.zip)
- Unzip it

OLD WAY:
```sh
ogr2ogr -f GeoJSON water-polygons-split.json water-polygons-split-4326/water_polygons.shp
tippecanoe -o water-tiles.mbtiles --force --maximum-zoom=15 --minimum-zoom=2 --drop-densest-as-needed --coalesce-densest-as-needed --simplify-only-low-zooms --coalesce --layer=water --exclude-all --read-parallel water-polygons-split.json
```

IMPORT FROM SHP INTO POSTGIS:
```sh
shp2pgsql -I -s 4326 data/water-polygons-split-small/water.shp water_small | PGPASSWORD='my_secure_password' PGPASSWORD=my_secure_password psql -h localhost -p 5432 -d oomap -U oom_user
```

## Contour lines

- geotiff
- create vrt from geotiff
- 

```sh
gdalwarp -of VRT -r cubic data/srtm_germany_dtm.tif -ts 52804 43204 -overwrite data/srtm_germany_dtm.vrt
gdal_contour -a ele -i 10 data/srtm_germany_dtm.vrt data/contour.gpkg
OGR_GEOJSON_MAX_OBJ_SIZE=0 ogr2ogr -f "PostgreSQL" PG:"dbname=oomap host=localhost port=5432 user=oom_user password=my_secure_password" data/contour.geojson -nln contours -overwrite --config PG_USE_COPY YES -gt 65536 -lco GEOMETRY_NAME=geom
```

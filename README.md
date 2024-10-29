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

- `data/map.osm.pbf` (Initial download)
- TODO pyosmium-up-to-date (Update mapdata)
- osm2pgsql (convert osm to postgis)
- martin (on the fly vector tiles renderer)
- maputnik (style editing)
- Maplibre GL (rendering)

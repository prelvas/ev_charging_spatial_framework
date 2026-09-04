# ------------------------------------------------------------------------------------------------------------------------------
#           Rede Rodoviária Nacional
#   - Source
#       - https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/metadata/70ea24cf-ef0b-4fd0-810c-8d3ea95acb6d
#   
#   Período temporal:
#       - fev.23 a dez.24
# 
#   - formato:
#       - SHAPEFILE (SHP)  
# ------------------------------------------------------------------------------------------------------------------------------
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

import geopandas as gpd
import psycopg2
from shapely import wkb, LineString, MultiLineString

from db.config import DB_CONFIG

# Ler o Shapefile 
gdf = gpd.read_file("../data/rede_rodoviaria_nacional/Rede_Rodoviaria.shp")
print(gdf.columns)
print(gdf.head)


# Confirmar ou converter para EPSG:3763
if gdf.crs.to_epsg() != 3763:
    gdf = gdf.to_crs(epsg=3763)

# Conexão à BD
conn = psycopg2.connect(**DB_CONFIG)
cur = conn.cursor()

# Script de inserção
insert_sql = """
INSERT INTO rede_rodoviaria (                          
    road_number, categoria, distrito, road_1, road_2, road_3, road_4, estado, gestao, n_vias, geom
)
VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,  ST_SetSRID(%s::geometry, 3763) );
"""


for idx, row in gdf.iterrows():
    geom = row['geometry']
    if isinstance (geom, (LineString, MultiLineString)):
        geom_wkb = geom.wkb
    else:
        print(f"Geometria inválida na linha {idx}, ignorada.")
        continue

    cur.execute(insert_sql, (
        row['roadnumber'],
        row['categoria'],
        row['distrito'],
        row['road1'],
        row['road2'],
        row['road3'],
        row['road4'],
        row['estado'],
        row['gestao'],
        row['n_vias'],
        (psycopg2.Binary(geom_wkb))
    ))

conn.commit()
cur.close()
conn.close()

print("Upload da Rede Rodoviária Nacional concluído com sucesso.")
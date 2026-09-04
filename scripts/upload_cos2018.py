# ------------------------------------------------------------------------------------------------------------------------------
#           COS2018 :: Ler Geopackage   
#
#   - Source:
#   https://snig.dgterritorio.gov.pt/rndg/srv/por/catalog.search#/search?anysnig=COS2018&fast=index
#
#   - formato:
#       - GEOPACKAGE (GPKG)
# ------------------------------------------------------------------------------------------------------------------------------
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

import geopandas as gpd
import psycopg2
from psycopg2.extras import execute_values
from shapely import wkb
from db.config import DB_CONFIG

# Ler GeoPackage
gdf = gpd.read_file("../data/cos2018/cos2018v2.gpkg", layer="COS2018v2")
#print(gdf.columns)
#print(gdf.head)
#print(f"Total de linhas: {len(gdf)}")


# Confirmar ou converter para EPSG:3763
if gdf.crs.to_epsg() != 3763:
    gdf = gdf.to_crs(epsg=3763)

# Conexão à BD
conn = psycopg2.connect(**DB_CONFIG)
cur = conn.cursor()

# SQL base
insert_sql = """
INSERT INTO cos_2018 (
    cos_fid, cos18n1_c, cos18n1_l, cos18n2_c, cos18n2_l,
    cos18n3_c, cos18n3_l, cos18n4_c, cos18n4_l, area_ha, geom
)
VALUES %s
"""

# Preparar os dados - colunas (para inserção com SetSRID)
records = [
    (
        row['ID'],
        row['COS18n1_C'],
        row['COS18n1_L'],
        row['COS18n2_C'],
        row['COS18n2_L'],
        row['COS18n3_C'],
        row['COS18n3_L'],
        row['COS18n4_C'],
        row['COS18n4_L'],
        float(row['Area_ha']),
        row['geometry'].wkb
    )
    for _, row in gdf.iterrows()
]

# Inserir em batches
batch_size = 10000
for i in range(0, len(records), batch_size):
    batch = records[i:i+batch_size]
    print(f"Inserir batch {i} até {i+len(batch)}...")
    execute_values(
        cur,
        insert_sql,
        batch,
        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, ST_SetSRID(ST_GeomFromWKB(%s), 3763))"
    )
    conn.commit()

cur.close()
conn.close()
print("Upload do COS2018 concluído com sucesso.")


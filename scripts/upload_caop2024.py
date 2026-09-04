# ------------------------------------------------------------------------------------------------------------------------------
#           CAOP2024 :: Ler Shapefile  
#   - Source:
#       https://www.dgterritorio.gov.pt/dados-abertos
#
#   - formato:
#       - GEOPACKAGE (GPKG)
#       - SHAPEFILE (SHP) - não usado
#
#   - leitura do TIPO=municipio (gpkg) a partir do geopackage geral
#           :: em alternativa ler diretamente apenas o geopackage:
#               - continente_municipio  
# ------------------------------------------------------------------------------------------------------------------------------
import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

import geopandas as gpd
import psycopg2
from shapely import wkb
from db.config import DB_CONFIG

# Ler o Shapefile     
# # alternativa era ler diretamente apenas o geopackage continente_municipio - leitura do TIPO=municipio a partir do shapefile geral
"""gdf_ = gpd.read_file("../data/caop2024/caop2024_shapefile.shp")
gdf_municipios = gdf_[gdf_['tipo'] == 'MUNICÍPIO']
#gdf_municipios.to_file("../data/caop2024/Cont_Municipios.shp")
print(gdf_municipios.columns)
"""

# Ler o GeoPackage
gdf = gpd.read_file("../data/caop2024/caop2024_cont_municipios.gpkg")
print(gdf.columns)
print(gdf.head)


# Confirmar ou converter para EPSG:3763
if gdf.crs.to_epsg() != 3763:
    gdf = gdf.to_crs(epsg=3763)

# Renomear colunas
"""gdf = gdf.rename(columns={
    'perimetro_': 'perimetro_km',
    'n_freguesi': 'n_freguesias'
})
"""

# Conexão à BD
conn = psycopg2.connect(**DB_CONFIG)
cur = conn.cursor()

# Script sql para inserção
insert_sql = """
    INSERT INTO caop_2024 (
        dtmn, municipio, distrito, nuts_3, nuts_2, nuts_1, area_ha, perimetro_km, n_freguesias, geom
    )
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, ST_SetSRID(ST_GeomFromWKB(%s), 3763) );
"""
for _, row in gdf.iterrows():
    cur.execute(insert_sql, (
        row['dtmn'],
        row['municipio'],
        row['distrito_ilha'],
        row['nuts3'],
        row['nuts2'],
        row['nuts1'],
        float(row['area_ha']),
        row['perimetro_km'],
        row['n_freguesias'],
        row['geometry'].wkb     # faz o extract the well-known binary de uma representação geográfica - obj do tipo geometry :: convert uma geometria (Point, LineString ou Polygono) para binário
    ))

conn.commit()
cur.close()
conn.close()

print("Upload do CAOP2024 (camada/nível Municípios) concluído com sucesso.")
# ---------------------------------------------------------------
#           LOCAIS DE CARREGAMENTO - PONTOS (new Maio 2016)
#
#   - Source:
#       - Mobi.E (dados fornecidos pela mobi.E)
#
#   - formato:
#       - ficheiro de excel (XLSX)
#
#   Período temporal:
#       - fev.23 a dez.24    
# ---------------------------------------------------------------

import sys
import pandas as pd
import numpy as np
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

import psycopg2
from psycopg2.extras import execute_batch
from db.config import DB_CONFIG


def to_float_or_none(value):
    if pd.isna(value):
        return None
    try:
        value_str = str(value).strip()
        if value_str == "" or value_str.lower() == "nan":
            return None
        return float(value_str)
    except (ValueError, TypeError):
        return None


def upload_csv(filepath, batch_size=1000):
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

#ST_Tranform(ST_SetSRID(ST_MakePoint(%s, %s), 4326), 3763)
    insert_sql = """
        INSERT INTO local_de_carregamento (
            id_charging_station, country_code, party_id, publish, name, address, city, postal_code, state, country, parking_type, access_type, mobie_point_delivery_code, pdgr_status, 
            facility, latitude, longitude, geom, 
            evse_uid, evse_id, status, connector_uid, standard, format, power_type, max_voltage, max_amperage, max_electric_power
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
            CASE 
                WHEN %s IS NOT NULL AND %s IS NOT NULL
                THEN ST_Transform(ST_SetSRID(ST_MakePoint(%s, %s), 4326), 3763)
                ELSE NULL
            END,
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        );
    """

    print(f"A abrir o ficheiro de Excel: {filepath}")
    
    # Carrega o ponteiro para o ficheiro de Excel
    excel_file = pd.ExcelFile(filepath)
    sheet_name = excel_file.sheet_names[0] # Aponta para a primeira folha do livro no ficheiro de excel
    
    # Ler apenas os cabeçalhos para identificar os nomes corretos das colunas
    header_df = pd.read_excel(filepath, nrows=0)
    original_columns = [col.strip().replace('\ufeff', '') for col in header_df.columns]

    skip_rows = 1  # Salta a primeira linha (que é o cabeçalho) 
    has_data = True

    while has_data:
        # Lê um bloco (chunk) do ficheiro
        chunk = excel_file.parse(
            sheet_name=sheet_name,
            skiprows=range(1, skip_rows), # Mantém a linha 0 (header) e salta as linhas já processadas
            nrows=batch_size
        )
        
        # Se o chunk estiver vazio, significa que atingiu o fim do ficheiro
        if chunk.empty:
            has_data = False
            break
            
        # Forçar a limpeza das colunas no chunk atual
        chunk.columns = original_columns
        
        # Substituir NaNs por None
        chunk = chunk.where(pd.notnull(chunk), None)
        
        batch_records = []
        rows_as_dicts = chunk.to_dict(orient='records')

        for row in rows_as_dicts:
            lat = to_float_or_none(row.get('latitude'))
            lon = to_float_or_none(row.get('longitude'))

            valor = row['max_electric_power']
            max_electric_power = None if np.isnan(valor) else int(valor)

            batch_records.append((
                row.get('location_uid'),
                row.get('country_code'),
                row.get('party_id'),
                row.get('publish'),
                row.get('name'),
                row.get('address'),
                row.get('city'),
                row.get('postal_code'),
                row.get('state'),
                row.get('country'),
                row.get('parking_type'),
                row.get('access_type'),
                row.get('mobie_point_delivery_code'),
                row.get('pdgr_status'),
                row.get('facility'),
                lat,
                lon,
                # --- Parâmetros PostGIS ---
                lat,
                lon,
                lon, # X (Longitude)
                lat, # Y (Latitude)
                # -------------------------
                row.get('evse_uid'),
                row.get('evse_id'),
                row.get('status'),
                row.get('connector_uid'),
                row.get('standard'),
                row.get('format'),
                row.get('power_type'),
                row.get('max_voltage'),
                row.get('max_amperage'),
                max_electric_power
            ))

        if batch_records:
            execute_batch(cur, insert_sql, batch_records)
            print(f"Inserir o lote de {len(batch_records)} registos (Linhas processadas: {skip_rows - 1 + len(batch_records)})")
        
        # faz avançar o ponteiro de linhas para o próximo lote (bacth)
        skip_rows += len(chunk)

    conn.commit()
    cur.close()
    conn.close()

    print("Upload concluído com sucesso.")

if __name__ == "__main__":
    # procura a pasta onde este script (.py) está guardado
    script_dir = Path(__file__).resolve().parent
    
    # constrói o caminho correto - sube até 'projetos' e entra no diretório: 'data/mobi/...'
    #  - como o script está em 'projetos/scripts', o .parent dele é: 'projetos/'
    projeto_raiz = script_dir.parent
    ficheiro_xlsx = projeto_raiz / "data" / "mobi" / "Postos_18052026_.xlsx"
    
    # chama a função e passa-lhe o caminho absoluto (já convertido to string)
    upload_csv(str(ficheiro_xlsx))
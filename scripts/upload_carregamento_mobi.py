# ---------------------------------------------------------------
#           SESSÕES DE CARREGAMENTO (new Maio 2016)
#   
#   - Source:
#       - Mobi.E (dados fornecidos pela mobi.E)
#
#   Período temporal:
#       - fev.23 a dez.24
# 
#   - formato:
#       - Ficheiro sem formatação separado por vírgulas (CSV)  
# ---------------------------------------------------------------

import sys
from pathlib import Path
sys.path.append(str(Path(__file__).resolve().parent.parent))

import csv
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime
from dateutil import parser
from db.config import DB_CONFIG

BATCH_SIZE = 10000  # batch size

def extrair_data_hora(valor_str):
    try:
        dt = parser.parse(valor_str)
        return dt, dt.strftime("%Y-%m-%d"), dt.strftime("%H:%M:%S")
    except Exception:
        return None, None, None

def to_float_safe(val):
    try:
        return float(val.replace(" ", "").replace(",", "."))
    except (ValueError, AttributeError, TypeError):
        return None

def to_int_safe(val):
    try:
        val = float(val.replace(" ", "").replace(",", "."))
        return int(val) if val.is_integer() else val
    except (ValueError, AttributeError, TypeError):
        return None

def upload_csv(filepath):
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
        #last_updated, last_date_updated_charger, last_time_updated_charger,
    insert_sql = """
    INSERT INTO _pre_proc_carregamento_out_2023 (
        dt_crtd, date_crtd, time_crtd, dt_last_updt, date_last_updt, time_last_updt,
        cdr_id, connector_id, evse_id, total_cost_excl_vat, total_energy, total_duration, party_id,
        end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger,
        token_uid, 
        id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao , energia_total_periodo, energia_fora_vazio, 
        energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    )
    VALUES %s
    """

    valores_para_inserir = []

    with open(filepath, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=',')
        reader.fieldnames = [name.strip().replace('\ufeff', '') for name in reader.fieldnames]
        # print(reader.fieldnames)

        for i, row in enumerate(reader, start=1):
            # Tratamento das datas
            dt_crtd, date_crtd, time_crtd = extrair_data_hora(row['dt_crtd'])
            dt_last_updt, date_last_updt, time_last_updt = extrair_data_hora(row['dt_last_updt'])
            end_date_time, end_date_charger, end_time_charger = extrair_data_hora(row['end_date_time'])
            start_date_time, start_date_charger, start_time_charger = extrair_data_hora(row['start_date_time'])
            #last_updated, last_date_updated_charger, last_time_updated_charger = extrair_data_hora(row['last_updated'])

            valores_para_inserir.append((
                dt_crtd, date_crtd, time_crtd,
                dt_last_updt, date_last_updt, time_last_updt,
                row['cdr_id'],
                row['connector_uid'],
                row['evse_id'],
                float(row['total_cost_excl_vat']),
                float(row['total_energy']),
                float(row['total_time']),
                row['party_id'],
                #row['id_session'],
                end_date_time, end_date_charger, end_time_charger,
                start_date_time, start_date_charger, start_time_charger,
                #last_updated, last_date_updated_charger, last_time_updated_charger,
                #row['cdr_location_id'],
                row['cdr_token_uid'],
                #"",
                row['location_uid'],  # row['idchargingstation'],
                "", #row['nuts_1'],
                "", #row['opcao_horaria_ciclo'],
                row['nivel_tensao_transacao'],
                float(row['total_energia_total_periodo']), #float(row['energia_total_periodo']),
                float(row['energia_fora_vazio']),
                float(row['energia_ponta']),
                float(row['energia_cheias']),
                float(row['energia_vazio']),
                float(row['energia_vazio_normal']),
                float(row['energia_super_vazio'])
            ))

            # Quando atingir o tamanho do batch, insere e limpa buffer
            if i % BATCH_SIZE == 0:
                print(f"Inserir batch até à linha {i}...")
                execute_values(cur, insert_sql, valores_para_inserir)
                conn.commit()
                valores_para_inserir = []

        # Último batch
        if valores_para_inserir:
            print(f"A Inserir último batch com {len(valores_para_inserir)} registos...")
            execute_values(cur, insert_sql, valores_para_inserir)
            conn.commit()

    cur.close()
    conn.close()
    print("Upload completo do carregamento.")

if __name__ == "__main__":
    upload_csv("../data/mobi/20YY/OneDrive_1_1-1-2026/mm20YY.csv")
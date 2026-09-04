# ------------------------------------------------------------------------------------------------------------------------------
#           INE :: Dados dos census 
#   - Source:
#       https://www.ine.pt/xportal/xmain?xpid=INE&xpgid=ine_indicadores&contecto=pi&indOcorrCod=0012903&selTab=tab0
#
#   - formato:
#       - CSV (sem formatação separado por ponto e vírgula)
#
#   - Período: 
#       - data dos Censos [2021] (NUTS - 2013);
#       - População residente: por Local de residência, género e faixa etária
# ------------------------------------------------------------------------------------------------------------------------------
import sys
from pathlib import Path
import pandas as pd
import numpy as np

proj_path = str(Path(__file__).resolve().parent.parent)
#print(f"PATH:  {proj_path}")
sys.path.append(str(Path(__file__).resolve().parent.parent))

import psycopg2
from psycopg2.extras import execute_batch
from db.config import DB_CONFIG

def to_int_safe(val):
    try:
        if pd.isna(val):
            return None
        return int(str(val).replace(" ", "").replace("\xa0", ""))
    except (ValueError, TypeError):
        return None


def upload_csv(filepath, batch_size=1000):
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    insert_sql = """
        INSERT INTO ine_populacao_2021 (
            local_de_residencia, codigo_local_residencia, 
            hab_total_hm, hab_total_hm_15_24, hab_total_hm_25_64, hab_total_hm_mais_64, 
            hab_total_h, hab_total_h_15_24, hab_total_h_25_64, hab_total_h_mais_64, 
            hab_total_m, hab_total_m_15_24, hab_total_m_25_64, hab_total_m_mais_64
        ) VALUES (
            %s, %s, 
            %s, %s, %s, %s, 
            %s, %s, %s, %s, 
            %s, %s, %s, %s
        );
    """

    colunas = [
        "ano",
        "codigo_local_residencia",
        "Total_HM",
        "Total_HM_15_24_anos",
        "Total_HM_25_64_anos",
        "Total_HM_65_anos",
        "Total_H",
        "Total_H_15_24_anos",
        "Total_H_25_64_anos",
        "Total_H_65_anos",
        "Total_M",
        "Total_M_15_24_anos",
        "Total_M_25_64_anos",
        "Total_M_65_anos",
        "extra"
    ]

    reader = pd.read_csv(
        filepath,
        sep=";",
        encoding="latin1",
        skiprows=12,
        header=None,
        names=colunas,
        dtype=str,
        chunksize=batch_size
    )

    total_inseridos = 0

    while True:
        try:
            chunk = next(reader)
        except StopIteration:
            break

        chunk = chunk.where(pd.notnull(chunk), None)

        batch_records = []

        for row in chunk.to_dict(orient="records"):
            valor_local = row["codigo_local_residencia"]

            # para ignorar os rodapés e os metadados
            if not valor_local or ":" not in str(valor_local):
                continue

            codigo, local_residencia = str(valor_local).split(":", 1)

            batch_records.append((
                local_residencia.strip(),
                codigo.strip(),
                to_int_safe(row["Total_HM"]),
                to_int_safe(row["Total_HM_15_24_anos"]),
                to_int_safe(row["Total_HM_25_64_anos"]),
                to_int_safe(row["Total_HM_65_anos"]),
                to_int_safe(row["Total_H"]),
                to_int_safe(row["Total_H_15_24_anos"]),
                to_int_safe(row["Total_H_25_64_anos"]),
                to_int_safe(row["Total_H_65_anos"]),
                to_int_safe(row["Total_M"]),
                to_int_safe(row["Total_M_15_24_anos"]),
                to_int_safe(row["Total_M_25_64_anos"]),
                to_int_safe(row["Total_M_65_anos"])
            ))

        if batch_records:
            execute_batch(cur, insert_sql, batch_records)
            total_inseridos += len(batch_records)
            print(f"Inserir o lote de {len(batch_records)} registos")

    conn.commit()
    cur.close()
    conn.close()

    print(f"Upload concluído com sucesso. Total de registos: {total_inseridos}")

if __name__ == "__main__":
    upload_csv("data/ine/JoK9rwZVZ_3Y5fHfgGV0o85ojWCfISeQunc7tdxl_54073_PT_concelho_278.csv")

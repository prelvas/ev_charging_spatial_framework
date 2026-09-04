-- ------------------------------------------------------------------------------------------------------------------------------
--          SCRIPTS SQL PARA CRIAR AS TABELAS 
--
--  BAse de dados: PostgreSQL
--      -- A extensão PostGIS deve estar ativa
-- ------------------------------------------------------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS postgis;


-- create table pontos de carregamento
CREATE TABLE locais_de_carregamento (
    _id	SERIAL PRIMARY KEY,                             -- id
    id_charging_station VARCHAR(30) UNIQUE NOT NULL,    -- location_uid	
    country_code varchar(5),	
    party_id varchar(5), 
    publish	Boolean,
    name varchar(255),
    address	varchar(255),
    city varchar(50),
    postal_code	varchar(10),
    state varchar(30),
    country	varchar(5),
    --id_geo_location	
    parking_type varchar(255),
    -- time_zone	
    -- mobie_voltage_level	varchar(10),
    access_type	varchar(15),
    mobie_point_delivery_code varchar(255),
    pdgr_status	varchar(50),
    facility varchar(255),
    latitude DOUBLE PRECISION, 
    longitude DOUBLE PRECISION, 
    geom GEOMETRY(Point, 3763),                -- Coordenadas em lat/lon 4326-->(WGS84)	
    -- district TEXT null,
    -- municipio TEXT null,
    -- dtmn TEXT null,
    evse_uid varchar(150),
    evse_id varchar(150),
    status varchar(50),
    connector_uid varchar(150),
    standard varchar(80),
    format varchar(20),
    power_type varchar(20),
    max_voltage	INTEGER,
    max_amperage INTEGER,
    max_electric_power INTEGER
);

-- Criar tabelas das sessões de Carregamentos
CREATE TABLE _pre_proc_carregamento_dez_20YY (
    _id SERIAL PRIMARY KEY,                         -- ID numérico autoincrementado (poderá prescindir-se deste campo como PK)
    dt_crtd TIMESTAMP,                                  --
    date_crtd Date,                                     --
    time_crtd Time, 
    dt_last_updt TIMESTAMP,
    date_last_updt Date,
    time_last_updt Time,
    cdr_id VARCHAR(100),
    connector_id VARCHAR(30) NOT NULL,
    evse_id varchar(40),
    total_cost_excl_vat NUMERIC(21,15),  
    total_energy NUMERIC(21,15),
    total_duration NUMERIC(21,15),                  -- total_time
    party_id varchar(15),
    id_session INTEGER,
    end_date_time TIMESTAMP,
    end_date_charger Date,
    end_time_charger TIME,
    start_date_time TIMESTAMP,
    start_date_charger Date,
    start_time_charger Time,
    last_updated TIMESTAMP,
    last_date_updated_charger Date,
    last_time_updated_charger Time,
    cdr_location_id INTEGER,
    token_uid varchar(80),
    id_charging_station varchar(20),
    nuts_1 varchar(10),
    opcao_horaria_ciclo varchar(10),
    nivel_tensao_transacao varchar(10),
    energia_total_periodo NUMERIC(21,15),
    energia_fora_vazio NUMERIC(21,15),
    energia_ponta NUMERIC(21,15),
    energia_cheias NUMERIC(21,15),
    energia_vazio NUMERIC(21,15),
    energia_vazio_normal NUMERIC(21,15),
    energia_super_vazio NUMERIC(21,15)
    -- FOREIGN KEY (id_charging_station) REFERENCES ponto_de_carregamento(id_charging_station)
);


-- Criação da tabela 'cos_2018'                     
CREATE TABLE cos_2018 (
    _id SERIAL PRIMARY KEY,                             -- ID numérico autoincrementado 
    cos_fid INTEGER,                                    -- FID original - eventualmente retirar
    cos18n1_c varchar(10),                                  --       
    cos18n1_l varchar(100),                             --  
    cos18n2_c varchar(10),                                  --       
    cos18n2_l varchar(100),                             --  
    cos18n3_c varchar(10),                                  --       
    cos18n3_l varchar(100),                             --  
    cos18n4_c varchar(10),                                  --       
    cos18n4_l varchar(100),                             --  
    area_ha DOUBLE PRECISION,                              --
    geom GEOMETRY(MultiPolygon, 3763)                   -- geometria poligonal
);

-- Criação da tabela 'caop_2024'                     
CREATE TABLE caop_2024 (
    _id SERIAL PRIMARY KEY,                             -- ID numérico autoincrementado 
    dtmn varchar(6),                                    --
    municipio varchar(50),                              --       
    distrito varchar(50),                               --  
    nuts_3 varchar(100),                                --       
    nuts_2 varchar(50),                                 --       
    nuts_1 varchar(50),                                 --       
    area_ha DECIMAL(10,4),                              --
    perimetro_km INTEGER,                               --
    n_freguesias INTEGER,                               --
    geom GEOMETRY(MultiPolygon, 3763)                   -- geometria poligonal
);

-- Criação da tabela 'rede_rodoviaria'                     
CREATE TABLE rede_rodoviaria (
    _id SERIAL PRIMARY KEY,                             -- ID numérico autoincrementado
    road_number varchar(250),                            --
    categoria varchar(250),                             --
    distrito varchar(100),                               --
    road_1 varchar(100),                                 --
    road_2 varchar(100),                                 --
    road_3 varchar(100),                                 --
    road_4 varchar(100),                                 --
    estado varchar(100),                                 --
    gestao varchar(100),                                 --
    n_vias varchar(25),                                 --
    geom GEOMETRY(Geometry, 3763)                   -- geometria poligonal
);

-- tabela INE para carregar os dados a nível nacional do INE (census 2021) - para cruzar com caop e calcular nº hab/km2
CREATE TABLE ine_populacao_2021 (
    _id SERIAL PRIMARY KEY,                             -- ID numérico autoincrementado
    local_de_residencia TEXT,                           -- campo que identifica o local de residência
    codigo_local_residencia TEXT,                       -- código que identifica o local de residência
    hab_total_hm INTEGER,                               -- campo S7A2021:2021-T:HM-T:Total
    hab_total_hm_15_24 INTEGER,                         -- campo S7A2021:2021-T:HM-2:15 - 24 anos
    hab_total_hm_25_64 INTEGER,                         -- campo S7A2021:2021-T:HM-3:25 - 64 anos
    hab_total_hm_mais_64 INTEGER,                       -- campo S7A2021:2021-T:HM-4:65 e mais anos
    hab_total_h INTEGER,                                -- campo S7A2021:2021-1:H-T:Total
    hab_total_h_15_24 INTEGER,                          -- campo S7A2021:2021-1:H-2:15 - 24 anos
    hab_total_h_25_64 INTEGER,                          -- campo S7A2021:2021-1:H-2:25 - 64 anos
    hab_total_h_mais_64 INTEGER,                        -- campo S7A2021:2021-1:H-4:65 e mais anos
    hab_total_m INTEGER,                                -- campo S7A2021:2021-1:M-T:Total
    hab_total_m_15_24 INTEGER,                          -- campo S7A2021:2021-1:M-2:15 - 24 anos
    hab_total_m_25_64 INTEGER,                          -- campo S7A2021:2021-1:M-2:25 - 64 anos
    hab_total_m_mais_64 INTEGER                         -- campo S7A2021:2021-1:M-4:65 e mais anos
);

CREATE INDEX idx_cos2018_geom ON cos_2018 USING GIST (geom);
CREATE INDEX idx_caop2024_geom ON caop_2024 USING GIST (geom);
CREATE INDEX idx_carregamento_geom ON carregamento USING GIST (geom);


create index locais_de_carregamento_geom_idx on locais_de_carregamento using GIST(geom);
select Find_SRID('', 'locais_de_carregamento', 'geom');


/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
/* -----------------------------------PREPARAÇÂO DA TABELA LOCAL_DE_CARREGAMENTO (preservando original) (campos distrito,...)--------------------------------------------------*/
/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
/**
 * 	Adicionar os campos à tabela nova de pontos de carregamento:: local_de_carregamento (criada a partir de locais_de_carregamento_new)
 *    	-- criar nova tabela
 * 		-- normalizar a tabela locais de carregamento - adicionar o campo distrito
 * 		-- adicionar constraints e indexes
 * 		-- adicionar campos necessários à tabela LOCAL_DE_CARREGAMENTO (em minusculas)
 * 		-- union com caop2024 pela intersect da geom
 **/

-- Etapa 1: Cria a estrutura idêntica com ABSOLUTAMENTE tudo
CREATE TABLE local_de_carregamento (LIKE locais_de_carregamento_new INCLUDING ALL);

-- Etapa 2: Copia os dados
INSERT INTO local_de_carregamento SELECT * FROM locais_de_carregamento_new; -- 42743

-- Etapa 3: adicionar as colunas: dtmn INTEGER, municipio TEXT, distrito TEXT, nuts_3 TEXT, nuts_2 TEXT, nuts_1 TEXT)
-- select * FROM caop_2024 c limit 100;
ALTER TABLE local_de_carregamento ADD COLUMN distrito TEXT, ADD column municipio TEXT, ADD COLUMN dtmn INTEGER, ADD COLUMN nuts_3 TEXT, ADD COLUMN nuts_2 TEXT, ADD COLUMN nuts_1 TEXT;

-- Etapa 4: criar índices para melhorar a performance em termos de acesso: caop e local_de_carregamento
	-- Índice para os seus pontos
CREATE INDEX IF NOT EXISTS idx_local_carregamento_geom  ON local_de_carregamento USING gist(geom);

	-- Índice para os polígonos da CAOP
CREATE INDEX IF NOT EXISTS idx_caop_2024_geom  ON caop_2024 USING gist(geom);

-- Etapa 5: verificar qual o sistema de informação geográfico é que está a ser utilizado em ambas as tabelas SRID=3763
SELECT ST_SRID(geom) AS srid, COUNT(*)  FROM local_de_carregamento  WHERE geom IS NOT null GROUP BY srid; -- srid: 3763 count: 42743
SELECT ST_SRID(geom) AS srid, COUNT(*)  FROM caop_2024 c   WHERE geom IS NOT null GROUP BY srid; -- srid: 3763 -- count: 278

-- Etapa 6: Fazer a interceçao e ppopular os novos campos da tabela local_de_carregamento
UPDATE local_de_carregamento p
SET 
    distrito  = c.distrito,   
    municipio = c.municipio,   
    dtmn      = c.dtmn,    
    nuts_3    = c.nuts_3,      
    nuts_2    = c.nuts_2,      
    nuts_1    = c.nuts_1       
FROM caop_2024 c
WHERE ST_Within(p.geom, c.geom); -- apenas atualizou 41745 das 42743
-- select count(*) from local_de_carregamento ldc where ldc.nuts_1 = 'Continente';

UPDATE local_de_carregamento p
SET 
    distrito  = c.distrito,   
    municipio = c.municipio,   
    dtmn      = LEFT(c.dtmn, 4),    
     nuts_3    = c.nuts_3,      
     nuts_2    = c.nuts_2,      
     nuts_1    = c.nuts_1        
FROM caop_2024 c
WHERE p.distrito IS NULL -- APENAS para aplicar aos 998 pontos que falharam
  AND ST_DWithin(p.geom, c.geom, 5); -- Procura o polígono da CAOP a até 5 metros de distância
 
SELECT 
    id_charging_station, city,
    ST_Y(ST_Transform(geom, 4326)) AS latitude,
    ST_X(ST_Transform(geom, 4326)) AS longitude
FROM local_de_carregamento
WHERE distrito IS NULL
LIMIT 1000;


/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
/* <V1>----------------------- PREPARAÇÂO DA TABELA de SESSÕES DE CARREGAMENTO (carregamento_MES_20YY) -------------------------------------------------*/
--                  - preservando a tabela original: _pre_proc_carregamento_MES_20YY, criar novas tabelas para usar posteriormente para 
--      OBJETIVO:
--          - Limpar os registos cuja: 
--                  * energia_total_periodo <=0
--                  * tempo de carregamento (end_date_time - start_date_time) seja inferior a 2minutos ou superior a 48horas
/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
-- Query aplicada para os restantes meses 
--      - após correr a query e no processo de validação, verificou-se a existência de registos duplicados (id_session; start_date_time; end_date_time; ... ; mesmos valores de duração e energia)
--      - executada a versão V2 (abaixo)
CREATE TABLE carregamento_nov_2023  AS
		SELECT *
			FROM _pre_proc_carregamento_nov_2023
			WHERE (end_date_time - start_date_time) BETWEEN INTERVAL '2 minutes' AND INTERVAL '48 hours' and energia_total_periodo >0;

/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
/* <V2>----------------------- PREPARAÇÂO DA TABELA de SESSÕES DE CARREGAMENTO (carregamento_MES_20YY) -------------------------------------------------*/
--                  - preservando a tabela original: _pre_proc_carregamento_MES_20YY, criar novas tabelas para usar posteriormente para 
--      OBJETIVO:
--          - Limpar os registos cuja: 
--                  * energia_total_periodo <=0
--                  * tempo de carregamento (end_date_time - start_date_time) seja inferior a 2minutos ou superior a 48horas
--                  * registos únicos validados com 
/* -----------------------------------------------------------------------------------------------------------------------------------------------------*/
CREATE TABLE carregamento_jan_2024_fix AS
SELECT DISTINCT ON (
	id_session,
    start_date_time
) *
FROM _pre_proc_carregamento_jan_2024
WHERE (end_date_time - start_date_time) BETWEEN INTERVAL '2 minutes' AND INTERVAL '48 hours' AND energia_total_periodo > 0
ORDER by
	id_session,
    start_date_time,
    end_date_time DESC;
    */
-- fim de create to fix (V2)

-- versão criada em 04-06-2026 para a correção de informação trocada no csv
-- foram tb retirados os campos:  dt_crtd, date_crtd, time_crtd, dt_last_updt, date_last_updt, time_last_updt, cdr_id,id_session,
CREATE VIEW v_carregamentos_all AS
SELECT 
    *,
    DATE_TRUNC('month', t.start_date_charger) AS month,
    CASE 
        WHEN t.total_energy = 0 OR t.total_duration = 0 THEN 0
        ELSE 1
    END AS valid_session
FROM (
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_fev_2023_fix
    UNION ALL
    SELECT _id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_mar_2023_fix
    UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_abr_2023_fix
    UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_mai_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_jun_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_jul_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_energy::numeric AS total_duration, 
    	total_duration::numeric AS total_energy,
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_ago_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * CORREÇÃO: estes campos estão trocados no csv
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_set_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_out_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_nov_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_dez_2023_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_jan_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_fev_2024_fix
    UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_mar_2024_fix
    UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_abr_2024_fix
    UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_mai_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_jun_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_jul_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_ago_2024_fix
     UNION ALL
    SELECT 
	    _id, connector_id, evse_id, total_cost_excl_vat, 
	    	/*
	    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
	    	 */
    		total_duration::numeric AS total_duration,
	    	total_energy::numeric AS total_energy, 
	    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
   FROM carregamento_set_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_out_2024_fix
     UNION ALL
    SELECT 
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_nov_2024_fix
     UNION ALL
    SELECT  
    	_id, connector_id, evse_id, total_cost_excl_vat, 
    	/*
    	 * validados com os campos de energia: energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    	 */
    	total_duration::numeric AS total_duration,
    	total_energy::numeric AS total_energy, 
    	party_id,  end_date_time, end_date_charger, end_time_charger, start_date_time, start_date_charger, start_time_charger, last_updated, last_date_updated_charger, last_time_updated_charger, cdr_location_id, token_uid, id_charging_station, nuts_1, opcao_horaria_ciclo, nivel_tensao_transacao, energia_total_periodo, energia_fora_vazio, energia_ponta, energia_cheias, energia_vazio, energia_vazio_normal, energia_super_vazio
    FROM carregamento_dez_2024_fix
) t;
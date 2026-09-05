
-- ===============================================================================
-- VIEWS USADAS PIPELINE ANALITICA
-- ===============================================================================


/* =============================================================================
 * 00 — Base territorial, infraestrutura e limpeza de sessões
 * ============================================================================= */


-- -----------------------------------------------------------------------------
-- v00_caop_municipios
-- Prepara os limites municipais da CAOP2024 e garante geometrias válidas
-- -----------------------------------------------------------------------------
-- v00_municipios --
DROP VIEW IF EXISTS v00_caop_municipios CASCADE;
CREATE VIEW v00_caop_municipios AS
SELECT
	dtmn,
	municipio,
	distrito,
	nuts_3,
	nuts_2,
	nuts_1,
	area_ha,
	perimetro_km,
	n_freguesias,
	ST_MakeValid(geom) AS geom
FROM caop_2024
WHERE geom IS NOT NULL;

-- ---------------------------------------------------------------------------------
-- v00_postos_unicos
-- Registos da infraestrutura num único registo por estação de carregamento
-- ---------------------------------------------------------------------------------
-- v00_postos_unicos
DROP VIEW IF EXISTS v00_postos_unicos CASCADE;
CREATE VIEW v00_postos_unicos AS
SELECT
    id_charging_station,
    MAX(distrito) AS distrito,
    MAX(municipio) AS municipio,
    MAX(dtmn) AS dtmn,
    MAX(nuts_3) AS nuts_3,
    MAX(nuts_2) AS nuts_2,
    MAX(nuts_1) AS nuts_1,
    ST_PointOnSurface(ST_Collect(geom)) AS geom
FROM local_de_carregamento
GROUP BY id_charging_station;

-- ---------------------------------------------------------------------------------------------
-- v00_postos_unicos_continente
-- Filtrar as estações únicas ao território continental (exclui regiões Autónomas)
-- ---------------------------------------------------------------------------------------------
-- v00_postos_unicos_continente   -- apenas o Continente
DROP VIEW IF EXISTS v00_postos_unicos_continente CASCADE;
CREATE OR REPLACE VIEW v00_postos_unicos_continente AS
SELECT *
FROM v00_postos_unicos
WHERE TRIM(nuts_1) = 'Continente';

-- -----------------------------------------------------------------------------
-- v01_postos_unicos_continente_all_data
-- Disponibilizar todos os registos da infraestrutura localizados no Continente
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v01_postos_unicos_continente_all_data CASCADE;
CREATE OR REPLACE VIEW v01_postos_unicos_continente_all_data AS
SELECT *
FROM local_de_carregamento
WHERE TRIM(nuts_1) = 'Continente';


/*
 * -----------------------------------------------------------------------------------
 *  					------ 03_oferta_infraestrutura.sql -----
 *                              (Infraestrutura instalada)
 * -----------------------------------------------------------------------------------
 */
DROP VIEW IF EXISTS v20_oferta_posto CASCADE;
CREATE VIEW v20_oferta_posto AS
SELECT
    id_charging_station,
    distrito,
    municipio,
    dtmn,
    nuts_3,
    nuts_2,
    nuts_1,
    COUNT(DISTINCT evse_uid) AS n_evse,
    COUNT(DISTINCT connector_uid) AS n_conectores,
    MAX(max_electric_power) AS potencia_max_w,
    SUM(max_electric_power) AS potencia_total_w,
    AVG(max_electric_power) AS potencia_media_w,
    MAX(max_electric_power) / 1000.0 AS potencia_max_kw,
    SUM(max_electric_power) / 1000.0 AS potencia_total_kw,
    AVG(max_electric_power) / 1000.0 AS potencia_media_kw,
    MAX(CASE WHEN power_type ILIKE '%DC%' THEN 1 ELSE 0 END) AS tem_dc,
    MAX(CASE WHEN max_electric_power >= 50000 THEN 1 ELSE 0 END) AS tem_rapido,
    SUM(CASE WHEN power_type ILIKE '%DC%' THEN 1 ELSE 0 END) AS n_conectores_dc,
    SUM(CASE WHEN max_electric_power >= 50000 THEN 1 ELSE 0 END) AS n_conectores_rapidos,
    ST_PointOnSurface(ST_Collect(geom)) AS geom
FROM local_de_carregamento
WHERE TRIM(nuts_1) = 'Continente'
GROUP BY
    id_charging_station,
    distrito,
    municipio,
    dtmn,
    nuts_3,
    nuts_2,
    nuts_1;

-- -----------------------------------------------------------------------------
-- v01_sessoes_validas
-- View base das sessões válidas com as variáveis temporais e territoriais
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v01_sessoes_validas CASCADE;
CREATE OR REPLACE VIEW v01_sessoes_validas AS
SELECT
    -- Identificadores
    c._id,
    -- c.cdr_id, 				-- campo interno da mobie sem relevância para o estudo
    -- c.id_session,			-- campo interno da mobie sem relevância para o estudo
    c.id_charging_station,
    c.evse_id AS evse_id_raw,	-- campo que pode ser diferente dependendo do mês/ano
    c.connector_id,
    /*
     * Remove tudo após o último hífen
     * 	um evse_UID corresponde ao connector_uid sem o que surge após o útimo hífen
     * 	ex.:	evse_UID			evse_ID					  connector_UID
 	 * 			ACCBS-00001-1	PT*MOB*E*ACCBS*00001*1		ACCBS-00001-01-01
     */
    REGEXP_REPLACE(c.connector_id, '-[^-]+$', '') AS evse_uid_estimado,
    /*
     *  -- Corrige um problema de dados que vêm do CSV
     * 		- token_uid tem registos com valor do tipo string 'NULL'
     */
    NULLIF(c.token_uid, 'NULL') AS token_uid,
    CASE
        WHEN NULLIF(c.token_uid, 'NULL') IS NOT NULL THEN 1
        ELSE 0
    END AS tem_token_uid,
    -- Datas
    c.start_date_time,
    c.end_date_time,
    -- Métricas da sessão
    c.total_duration,
    c.total_energy,
    c.total_cost_excl_vat,
    -- Tarifário
    c.energia_total_periodo,
    c.energia_fora_vazio,
    c.energia_ponta,
    c.energia_cheias,
    c.energia_vazio,
    c.energia_vazio_normal,
    c.energia_super_vazio,
    -- Validação da duração
    /*
     * Para validar se a diferença entre a subtração entre end_date_time por star_date_time
     * 		corresponde ao mesmo valor ou mto aproximado do campo total_duration
     * 	PROBLEMA:
     * 		Numa fase inicial a Mobie não controlava se o veículo continuava connectado,
     * 		o tempo de carregamento usando esta fórmula de validação, nem sempre corresponde, e no ano de 2023 é pior
     * 	Não dar demasiada importância ao campo :: assumir o tempo de duraçã como total_duration
     */
    EXTRACT(EPOCH FROM (c.end_date_time - c.start_date_time)) / 60.0
        AS duracao_calculada_min,
    ABS(
        c.total_duration -
        (EXTRACT(EPOCH FROM (c.end_date_time - c.start_date_time)) / 60.0)
    ) AS diff_duracao_min,
    -- Variáveis temporais
    DATE_TRUNC('month', c.start_date_time)::DATE AS mes,
    EXTRACT(HOUR FROM c.start_date_time)::int AS hora_inicio,
    EXTRACT(DOW FROM c.start_date_time)::int AS dia_semana,
    EXTRACT(MONTH FROM c.start_date_time)::int AS mes_num,
    EXTRACT(YEAR FROM c.start_date_time)::int AS ano,
    /*
     * calcular períodos de utilização com base na start_date_time
     * 	  - para identificar perfis de utilização
     */
    CASE
        WHEN EXTRACT(DOW FROM c.start_date_time) IN (0,6)
        THEN 1 ELSE 0
    END AS fim_semana,
    CASE
        WHEN EXTRACT(HOUR FROM c.start_date_time) BETWEEN 7 AND 21
        THEN 1 ELSE 0
    END AS periodo_diurno,
    -- nova categorização do periodo das sessões dado que havia sobreposição entre periodo diurno e laboral
    	-- a categorização acima ainda irá ficar até testar as dependencias -(embora não existam, optou-se por manter)
    	-- no caso do horario laboral alterado para apanhar apenas o horário laboral em dias de semana
    CASE
	    WHEN EXTRACT(ISODOW FROM c.start_date_time) BETWEEN 1 AND 5			-- ISODOW - para obter os dias da semana: seg. = 1, ... sext=5
	     AND EXTRACT(HOUR FROM c.start_date_time) BETWEEN 9 AND 17
	    THEN 1
	    ELSE 0
	END AS horario_laboral,
    CASE
	    WHEN EXTRACT(HOUR FROM c.start_date_time) BETWEEN 0 AND 6
	        THEN 'madrugada'
	    WHEN EXTRACT(HOUR FROM c.start_date_time) BETWEEN 7 AND 8
	        THEN 'manha_cedo'
	    WHEN EXTRACT(HOUR FROM c.start_date_time) BETWEEN 9 AND 17
	        THEN 'laboral'
	    WHEN EXTRACT(HOUR FROM c.start_date_time) BETWEEN 18 AND 21
	        THEN 'noite'
	    ELSE 'noite_tardia'
	END AS periodo_dia,
	-- nova categorização para a estação do ano
	CASE
	    WHEN EXTRACT(MONTH FROM c.start_date_time) IN (12, 1, 2)
	        THEN 'inverno'
	    WHEN EXTRACT(MONTH FROM c.start_date_time) IN (3, 4, 5)
	        THEN 'primavera'
	    WHEN EXTRACT(MONTH FROM c.start_date_time) IN (6, 7, 8)
	        THEN 'verao'
	    ELSE 'outono'
	END AS estacao_ano,
    -- Informação territorial
    p.distrito,
    p.municipio,
    p.dtmn,
    p.nuts_3,
    p.nuts_2,
    p.nuts_1,
    -- Geometria
    p.geom
FROM v_carregamentos_all c
INNER JOIN v00_postos_unicos_continente p ON c.id_charging_station = p.id_charging_station
WHERE c.valid_session = 1
  AND c.start_date_time IS NOT NULL
  AND c.end_date_time IS NOT NULL
  AND c.id_charging_station IS NOT NULL;

-- --------------------------------------------------------------------------------------------------------
-- v01_sessoes_validas_clean
-- Remover as sessões fisicamente inconsistentes do total de sessões válidas (v01_sessoes_validas)
--          (PROBLEMA DOS OUTLIERS - detetados com o KMEANS cluster com n=1)
-- --------------------------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v01_sessoes_validas_clean CASCADE;
-- to remove outliers = erro de registo
CREATE VIEW v01_sessoes_validas_clean AS
SELECT s.*
FROM v01_sessoes_validas s
JOIN v20_oferta_posto o
    ON s.id_charging_station = o.id_charging_station
WHERE o.potencia_max_kw IS NULL
   OR s.total_energy <= 5 * (o.potencia_max_kw * s.total_duration);

-- ------------------------------------------------------------------------------------------------------
-- v01_sessoes_feriados
-- Associae cada sessão válida aos feriados nacionais/municipais e classifica tb o tipo de dia
-- ------------------------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v01_sessoes_feriados CASCADE;
CREATE OR REPLACE VIEW v01_sessoes_feriados AS
SELECT
    s.*,
    CASE
        WHEN fn.id IS NOT NULL THEN 1
        ELSE 0
    END AS feriado_nacional,
    CASE
        WHEN fm.id IS NOT NULL THEN 1
        ELSE 0
    END AS feriado_municipal,
    CASE
        WHEN fn.id IS NOT NULL OR fm.id IS NOT NULL THEN 1
        ELSE 0
    END AS feriado,
    CASE
        WHEN fn.id IS NOT NULL THEN 'nacional'
        WHEN fm.id IS NOT NULL THEN 'municipal'
        ELSE NULL
    END AS ambito_feriado,
    COALESCE(fn.designacao, fm.designacao)
        AS designacao_feriado,
    CASE
        WHEN fn.id IS NOT NULL THEN 'feriado_nacional'
        WHEN fm.id IS NOT NULL THEN 'feriado_municipal'
        WHEN s.fim_semana = 1 THEN 'fim_semana'
        ELSE 'dia_util'
    END AS tipo_dia
FROM v01_sessoes_validas_clean s
LEFT JOIN feriado fn
    ON fn.data = s.start_date_time::DATE
   AND fn.ambito = 'nacional'
LEFT JOIN feriado fm
    ON fm.data = s.start_date_time::DATE
   AND fm.ambito = 'municipal'
   AND fm.dtmn = s.dtmn;

-- ------------------------------------------------------------------------------------
-- v14_procura_posto_clean
-- Agregar os indicadores finais de procura por posto (base: sessões clean)
-- ------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v14_procura_posto_clean CASCADE;
CREATE VIEW v14_procura_posto_clean AS
SELECT
	id_charging_station,
    MAX(distrito) AS distrito,
    MAX(municipio) AS municipio,
    MAX(dtmn) AS dtmn,
    MAX(nuts_3) AS nuts_3,
    MAX(nuts_2) AS nuts_2,
    MAX(nuts_1) AS nuts_1,
    ST_PointOnSurface(ST_Collect(geom)) AS geom,
    COUNT(*) AS n_sessoes,
    COUNT(DISTINCT connector_id) AS n_conectores_ativos,
    COUNT(DISTINCT evse_uid_estimado) AS n_evse_estimados_ativos,
    /*
     * Só a partir de SET23 é que o campo token_uid foi preenchido
     * representa o número de utilizadores a partir de set23 a dez24
    */
    COUNT(DISTINCT token_uid) AS n_utilizadores_unicos,
    COUNT(DISTINCT CASE
	   WHEN ano = 2023 THEN token_uid END) AS n_utilizadores_set_dez_2023,
	COUNT(DISTINCT CASE
	    WHEN ano = 2024 THEN token_uid END) AS n_utilizadores_2024,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_energy) AS energia_mediana_kwh,
    AVG(duracao_calculada_min) AS duracao_media_min,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duracao_calculada_min) AS duracao_mediana_min,
    SUM(total_cost_excl_vat) AS custo_total,
    AVG(total_cost_excl_vat) AS custo_medio,
    COUNT(DISTINCT mes) AS meses_ativos,
    MIN(start_date_time) AS primeira_sessao,
    MAX(start_date_time) AS ultima_sessao,
    COUNT(*)::numeric / NULLIF(COUNT(DISTINCT mes), 0) AS sessoes_mes_ativo,
    SUM(total_energy)::numeric / NULLIF(COUNT(DISTINCT mes), 0) AS kwh_mes_ativo,
    AVG(fim_semana::numeric) AS pct_fim_semana,
    AVG(periodo_diurno::numeric) AS pct_diurno,
    AVG(horario_laboral::numeric) AS pct_horario_laboral,
    SUM(energia_ponta) AS energia_ponta_kwh,
    SUM(energia_cheias) AS energia_cheias_kwh,
    SUM(energia_vazio) AS energia_vazio_kwh,
    SUM(total_energy)::numeric /NULLIF(COUNT(*), 0) AS kwh_por_sessao, 						-- qta energia é consumida em cada sessão em média;
	SUM(total_energy)::numeric /NULLIF(COUNT(DISTINCT token_uid), 0) AS kwh_por_utilizador, -- intensidade de utilização por utilizador
    SUM(energia_ponta)::numeric / NULLIF(SUM(total_energy), 0) AS pct_ponta,
    SUM(energia_cheias)::numeric / NULLIF(SUM(total_energy), 0) AS pct_cheias,
    SUM(energia_vazio)::numeric / NULLIF(SUM(total_energy), 0) AS pct_vazio,
    SUM(CASE WHEN mes_num IN (6,7,8,9) THEN 1 ELSE 0 END)::numeric / COUNT(*) AS pct_sessoes_verao,
    SUM(CASE WHEN mes_num IN (12,1,2) THEN 1 ELSE 0 END)::numeric / COUNT(*) AS pct_sessoes_inverno,
	/*
	 * Calcular a média de sessões por utilizador
	 * 	n_sessões/n_utilizadores_unicos
	 */
    COUNT(*)::numeric / NULLIF(
        COUNT(DISTINCT CASE
            WHEN token_uid IS NOT NULL THEN token_uid
        END),
        0
    ) AS sessoes_por_utilizador,
    -- novo para categorizar o periodo e as estacoes
    AVG((periodo_dia = 'madrugada')::int) AS pct_madrugada,
	AVG((periodo_dia = 'manha_cedo')::int) AS pct_manha_cedo,
	AVG((periodo_dia = 'laboral')::int) AS pct_laboral,
	AVG((periodo_dia = 'noite')::int) AS pct_noite,
	AVG((periodo_dia = 'noite_tardia')::int) AS pct_noite_tardia,
	-- estacao (novo)
	AVG((estacao_ano = 'inverno')::int) AS pct_inverno,
	AVG((estacao_ano = 'primavera')::int) AS pct_primavera,
	AVG((estacao_ano = 'verao')::int) AS pct_verao,
	AVG((estacao_ano = 'outono')::int) AS pct_outono,
	AVG(
	    (
	        periodo_dia IN ('madrugada','noite','noite_tardia')
	    )::int
	) AS pct_periodo_descanso,
	AVG(feriado::numeric) AS pct_feriado,
	AVG(feriado_nacional::numeric) AS pct_feriado_nacional,
	AVG(feriado_municipal::numeric) AS pct_feriado_municipal
FROM v01_sessoes_feriados -- v01_sessoes_validas_clean
GROUP BY id_charging_station;


/* =============================================================================
 *  — RQ1 — Procura observada e perfis temporais
 * --- 02_procura_observada.sql
 * =============================================================================*/

-- -----------------------------------------------------------------------------
-- v10_carregamentos_mes
-- Agregar as sessões e a energia por mês para a análise da evolução temporal
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v10_carregamentos_mes CASCADE;
CREATE OR REPLACE VIEW v10_carregamentos_mes AS
SELECT
    mes,
    COUNT(*) AS n_sessoes,
    COUNT(DISTINCT id_charging_station) AS n_postos_ativos,
    COUNT(DISTINCT evse_id_raw) AS n_evse_raw_ativos,
    COUNT(DISTINCT connector_id) AS n_conectores_ativos,
    COUNT(DISTINCT token_uid) AS n_utilizadores,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh,
    /*
     * Calcular a Mediana (percentile_cont(0.5) para obter a mediana
     * 		- útil para a existência de valores demasiado díspares
     * 		- caso o total de valores seja par, faz a interpolação
     */
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_energy) AS energia_mediana_kwh,
    AVG(duracao_calculada_min) AS duracao_media_min,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duracao_calculada_min) AS duracao_mediana_min,
    SUM(total_cost_excl_vat) AS custo_total,
    AVG(total_cost_excl_vat) AS custo_medio
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01'
GROUP BY mes
ORDER BY mes;


-- -----------------------------------------------------------------------------
-- v12_perfil_horario
-- Resumir as sessões e a energia por hora de início
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v12_perfil_horario CASCADE;
CREATE OR REPLACE VIEW v12_perfil_horario AS
SELECT
    hora_inicio,
    COUNT(*) AS n_sessoes,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
GROUP BY hora_inicio
ORDER BY hora_inicio;

-- -----------------------------------------------------------------------------
-- v12_perfil_horario_normalizado
-- Normalizar o perfil horário pelo número de dias observados
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v12_perfil_horario_normalizado AS
SELECT
    hora_inicio,
    COUNT(*) AS n_sessoes,
    COUNT(DISTINCT start_date_time::DATE) AS n_dias,
    COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia_hora,
    SUM(total_energy) AS energia_total_kwh,
    SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_hora_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01'
GROUP BY hora_inicio
ORDER BY hora_inicio;

-- -----------------------------------------------------------------------------
-- v13_perfil_semanal
-- Resumir as sessões e a energia por dia da semana
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v13_perfil_semanal CASCADE;
CREATE OR REPLACE VIEW v13_perfil_semanal AS
SELECT
    dia_semana,
    COUNT(*) AS n_sessoes,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
GROUP BY dia_semana
ORDER BY dia_semana;

-- -----------------------------------------------------------------------------------
-- v13_perfil_semanal_normalizado
-- Normalizar o perfil semanal pelo número de dias observados em cada dia da semana
-- Permite responder à questão: 
-- 			Qual o dia típico com mais carregamentos?
-- 				(usa a média por dia e não o total acumuldado)
-- -----------------------------------------------------------------------------------
DROP VIEW IF EXISTS v13_perfil_semanal_normalizado CASCADE;
CREATE OR REPLACE VIEW v13_perfil_semanal_normalizado AS
SELECT
	dia_semana,
	CASE dia_semana
		WHEN 0 THEN 'Sunday'
		WHEN 1 THEN 'Monday'
		WHEN 2 THEN 'Tuesday'
		WHEN 3 THEN 'Wednesday'
		WHEN 4 THEN 'Thursday'
		WHEN 5 THEN 'Friday'
		WHEN 6 THEN 'Saturday'
	END AS dia_semana_nome,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_kwh,
	AVG(total_energy) AS energia_media_por_sessao_kwh
	FROM v01_sessoes_validas_clean
	WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01'
	GROUP BY dia_semana
	ORDER BY dia_semana;

-- --------------------------------------------------------------------------------------
-- v13_weekday_weekend_normalizado
-- Comparar os dias úteis e os fins de semana
--			-- normalizarpelo número de dias observados
--			(para corrigir o problema da escala dos 5 dias vs 2 dias (fim-de-semana))
-- --------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v13_weekday_weekend_normalizado CASCADE;
CREATE OR REPLACE VIEW v13_weekday_weekend_normalizado AS
SELECT
	CASE
		WHEN fim_semana = 1 THEN 'weekend'
		ELSE 'weekday'
	END AS tipo_dia,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_kwh,
	AVG(total_energy) AS energia_media_por_sessao_kwh
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01'
GROUP BY fim_semana
ORDER BY tipo_dia;

-- ---------------------------------------------------------------------------------------
-- v13_perfil_horario_weekday_weekend
-- Calcular os perfis de horários separados para dias úteis e por fins de semana
-- view para criar um gráfico (análise) com o perfil horário: weekday vs weekend
-- ---------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v13_perfil_horario_weekday_weekend CASCADE;
CREATE OR REPLACE VIEW v13_perfil_horario_weekday_weekend AS
SELECT
	hora_inicio,
	CASE
		WHEN fim_semana = 1 THEN 'weekend'
		ELSE 'weekday'
	END AS tipo_dia,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia_hora,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_hora_kwh
	FROM v01_sessoes_validas_clean
	WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01'
	GROUP BY hora_inicio, fim_semana
	ORDER BY hora_inicio, tipo_dia;


/* =============================================================================
 * 			RQ1 — Agregações complementares da oferta
 * =============================================================================
 */
-- -----------------------------------------------------------------------------
-- v21_oferta_municipio
-- Agregar a oferta da infraestrutura ao nível do município
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v21_oferta_municipio CASCADE;
CREATE VIEW v21_oferta_municipio AS
SELECT
    municipio,
    distrito,
    dtmn,
	nuts_3,
    nuts_2,
    nuts_1,
    COUNT(DISTINCT id_charging_station) AS n_postos,
    COUNT(DISTINCT evse_id) AS n_evse_raw,
    COUNT(DISTINCT connector_uid) AS n_conectores,
    SUM(max_electric_power) / 1000.0 AS potencia_total_kw,
    MAX(max_electric_power) / 1000.0 AS potencia_max_kw,
    SUM(CASE WHEN power_type ILIKE '%DC%' THEN 1 ELSE 0 END) AS n_conectores_dc,
    SUM(CASE WHEN max_electric_power >= 50000 THEN 1 ELSE 0 END) AS n_conectores_rapidos
FROM local_de_carregamento
GROUP BY municipio, distrito, dtmn, nuts_3, nuts_2, nuts_1;


/* =============================================================================
 * 			 RQ2 — Features e tipologias de estações
 * =============================================================================
 */
-- -----------------------------------------------------------------------------
-- v30_features_cluster_posto_clean
-- Construir o conjunto final de features usado para o cluster (K-Means)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v30_features_cluster_posto_clean CASCADE;
CREATE VIEW v30_features_cluster_posto_clean AS
SELECT
    p.id_charging_station,
    -- Localização
    o.distrito,
    o.municipio,
    o.dtmn,
    o.nuts_3,
    o.nuts_2,
    o.nuts_1,
    o.geom,
    -- Procura observada
    p.n_sessoes,
    p.energia_total_kwh,
    p.energia_media_kwh,
    p.energia_mediana_kwh,
    p.duracao_media_min,
    p.duracao_mediana_min,
    p.meses_ativos,
    p.sessoes_mes_ativo,
    p.kwh_mes_ativo,
    -- Utilizadores / tokens
    p.n_utilizadores_unicos,
    p.n_utilizadores_set_dez_2023,
    p.n_utilizadores_2024,
    p.sessoes_por_utilizador,
    -- Padrões temporais
    p.pct_diurno,
    p.pct_horario_laboral,
    p.pct_sessoes_verao,
    p.pct_sessoes_inverno,
    -- novas categorias
    p.pct_feriado,
    p.pct_fim_semana,
	p.pct_periodo_descanso,
	p.pct_laboral,
	p.pct_verao,
	p.pct_inverno,
	-- fim das novas categorias temporais
    -- Tarifário
    p.pct_ponta,
    p.pct_cheias,
    p.pct_vazio,
    -- Procura técnica observada
    p.n_conectores_ativos,
    p.n_evse_estimados_ativos,
    -- Oferta instalada
    o.n_evse AS n_evse_instalados,
    o.n_conectores AS n_conectores_instalados,
    o.potencia_max_kw,
    o.potencia_total_kw,
    o.potencia_media_kw,
    o.tem_dc,
    o.tem_rapido,
    o.n_conectores_dc,
    o.n_conectores_rapidos,
    -- Indicadores normalizados
    p.n_sessoes::numeric / NULLIF(o.n_evse, 0) AS sessoes_por_evse_instalado,
    p.n_sessoes::numeric / NULLIF(o.n_conectores, 0) AS sessoes_por_conector_instalado,
    p.energia_total_kwh::numeric / NULLIF(o.potencia_total_kw, 0) AS kwh_por_kw_instalado,
    p.n_conectores_ativos::numeric / NULLIF(o.n_conectores, 0) AS taxa_conectores_ativos,
    p.n_evse_estimados_ativos::numeric / NULLIF(o.n_evse, 0) AS taxa_evse_ativos_estimados,		-- taxa_evse_ativos_estimados
    p.energia_total_kwh::numeric / NULLIF(p.n_sessoes, 0) AS kwh_por_sessao, 					-- Kwh por sessão
    p.energia_total_kwh::numeric / NULLIF(p.n_utilizadores_unicos, 0) AS kwh_por_utilizador 	-- kwh por utilizador
FROM v14_procura_posto_clean p
INNER JOIN v20_oferta_posto o
    ON p.id_charging_station = o.id_charging_station;

/* =============================================================================
 * 			RQ3 — Indicadores territoriais, pressão e análise espacial
 * 				------ 05_procura_potencial.sql -----
 * ============================================================================= */

-- -----------------------------------------------------------------------------
-- v40_indicadores_territoriais
-- Integrar os indicadores demográficos e territoriais por município
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v40_indicadores_territoriais CASCADE;
CREATE VIEW v40_indicadores_territoriais AS
SELECT
    c.dtmn,
    c.municipio,
    c.distrito,
    c.nuts_3,
    c.nuts_2,
    c.nuts_1,
    c.area_ha,
    c.area_ha /100.0 AS area_km2,
    c.perimetro_km,
    c.n_freguesias,
    c.geom,
    i.hab_total_hm AS populacao_total,
    i.hab_total_hm_15_24,
    i.hab_total_hm_25_64,
    i.hab_total_hm_mais_64,
    i.hab_total_h,
    i.hab_total_m,
    i.hab_total_hm / NULLIF(c.area_ha, 0) AS hab_por_ha,
    i.hab_total_hm / NULLIF(c.area_ha / 100.0, 0) AS densidade_pop_km2,
    i.hab_total_hm_15_24 / NULLIF(i.hab_total_hm, 0) AS pct_15_24,
    i.hab_total_hm_25_64 / NULLIF(i.hab_total_hm, 0) AS pct_25_64,
    i.hab_total_hm_mais_64 / NULLIF(i.hab_total_hm, 0) AS pct_mais_64
FROM caop_2024 c LEFT JOIN ine_populacao_2021 i ON c.dtmn = LPAD(i.codigo_local_residencia, 4, '0')
WHERE c.nuts_1 = 'Continente';

-- -----------------------------------------------------------------------------
-- v41_rede_viaria_municipio
-- Resumir a presença/extensão da rede viária por município
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v41_rede_viaria_municipio CASCADE;
CREATE VIEW v41_rede_viaria_municipio AS
WITH base AS (
    SELECT
        c.dtmn,
        c.municipio,
        c.distrito,
        c.nuts_3,
        c.nuts_2,
        c.nuts_1,
        c.area_ha / 100.0 AS area_km2,
        SUM(ST_Length(ST_Intersection(r.geom, c.geom))) / 1000.0 AS km_via_total,
        SUM(
            CASE
                WHEN r.categoria ILIKE '%Autoestrada%'
                  OR r.road_number ILIKE 'A%'
                THEN ST_Length(ST_Intersection(r.geom, c.geom))
                ELSE 0
            END
        ) / 1000.0 AS km_autoestrada,
        SUM(
            CASE
                WHEN r.road_number ILIKE 'IP%'
                THEN ST_Length(ST_Intersection(r.geom, c.geom))
                ELSE 0
            END
        ) / 1000.0 AS km_ip,
        SUM(
            CASE
                WHEN r.road_number ILIKE 'IC%'
                THEN ST_Length(ST_Intersection(r.geom, c.geom))
                ELSE 0
            END
        ) / 1000.0 AS km_ic
    FROM caop_2024 c
    LEFT JOIN rede_rodoviaria r
        ON ST_Intersects(r.geom, c.geom)
    WHERE c.nuts_1 = 'Continente'
    GROUP BY
        c.dtmn, c.municipio, c.distrito,
        c.nuts_3, c.nuts_2, c.nuts_1,
        c.area_ha
)
SELECT
    *,
    km_via_total / NULLIF(area_km2, 0) AS dens_vias_km2
FROM base;

-- -----------------------------------------------------------------------------------
-- v42_cobertura_populacional
-- Combinar a oferta de carregamento e a população para indicadores de cobertura
-- -----------------------------------------------------------------------------------
DROP VIEW IF EXISTS v42_cobertura_populacional CASCADE;
CREATE VIEW v42_cobertura_populacional AS
SELECT
    t.dtmn,
    t.municipio,
    t.distrito,
    t.nuts_3,
    t.nuts_2,
    t.nuts_1,
    t.populacao_total,
    t.densidade_pop_km2,
    COALESCE(o.n_postos, 0) AS n_postos,
    COALESCE(o.n_evse_raw, 0) AS n_evse,
    COALESCE(o.n_conectores, 0) AS n_conectores,
    COALESCE(o.potencia_total_kw, 0) AS potencia_total_kw,
    COALESCE(o.n_postos, 0) * 1000.0 / NULLIF(t.populacao_total, 0) AS postos_1000_hab,
    COALESCE(o.n_postos, 0) * 10000.0 / NULLIF(t.populacao_total, 0) AS postos_10000_hab,
    COALESCE(o.n_evse_raw, 0) * 1000.0 / NULLIF(t.populacao_total, 0) AS evse_1000_hab,
    COALESCE(o.n_evse_raw, 0) * 10000.0 / NULLIF(t.populacao_total, 0) AS evse_10000_hab,
    COALESCE(o.n_conectores, 0) * 1000.0 / NULLIF(t.populacao_total, 0) AS conectores_1000_hab,
    COALESCE(o.n_conectores, 0) * 10000.0 / NULLIF(t.populacao_total, 0) AS conectores_10000_hab,
    COALESCE(o.potencia_total_kw, 0) * 1000.0 / NULLIF(t.populacao_total, 0) AS kw_1000_hab,
    COALESCE(o.potencia_total_kw, 0) * 10000.0 / NULLIF(t.populacao_total, 0) AS kw_10000_hab,
    t.geom
FROM v40_indicadores_territoriais t
LEFT JOIN v21_oferta_municipio o
    ON t.dtmn = o.dtmn;

-- -----------------------------------------------------------------------------
-- v43_cobertura_viaria
-- Relacionar a oferta de carregamento com indicadores da rede viária
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v43_cobertura_viaria CASCADE;
CREATE VIEW v43_cobertura_viaria AS
SELECT
    t.dtmn,
    t.municipio,
    t.distrito,
	t.nuts_3,
    t.nuts_2,
    t.nuts_1,
    COALESCE(o.n_postos, 0) AS n_postos,
    COALESCE(o.n_evse_raw, 0) AS n_evse_raw,
    COALESCE(o.n_conectores, 0) AS n_conectores,
    COALESCE(o.potencia_total_kw, 0) AS potencia_total_kw,
    r.km_via_total,
    r.km_autoestrada,
    r.km_ip,
    r.km_ic,
    COALESCE(o.n_postos, 0) / NULLIF(r.km_via_total, 0) AS postos_por_km_via,
    COALESCE(o.n_evse_raw, 0) / NULLIF(r.km_via_total, 0) AS evse_por_km_via,
    COALESCE(o.potencia_total_kw, 0) / NULLIF(r.km_via_total, 0) AS kw_por_km_via,
    t.geom
FROM v40_indicadores_territoriais t
LEFT JOIN v21_oferta_municipio o ON t.dtmn = o.dtmn
LEFT JOIN v41_rede_viaria_municipio r ON t.dtmn = r.dtmn;

-- ----------------------------------------------------------------------------------------
-- v50_pressao_posto
-- Calcular indicadores de pressão/utilização da infraestrutura por posto de carregamento
-- ----------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v50_pressao_posto CASCADE;
CREATE OR REPLACE VIEW v50_pressao_posto AS
SELECT
    f.id_charging_station,
    f.distrito,
    f.municipio,
    f.dtmn,
    f.nuts_3,
    f.nuts_2,
    f.nuts_1,
    -- Procura observada
    f.n_sessoes,
    f.energia_total_kwh,
    f.sessoes_mes_ativo,
    f.kwh_mes_ativo,
    -- Utilizadores set 23 a dez 2024
    f.n_utilizadores_unicos,
    f.n_utilizadores_set_dez_2023,
    f.n_utilizadores_2024,
    f.sessoes_por_utilizador,  -- nº de sessões por utilizador (total / count (token_uid))
    -- Oferta instalada
    f.n_evse_instalados,
    f.n_conectores_instalados,
    f.potencia_total_kw,
    f.potencia_max_kw,
    f.tem_dc,
    f.tem_rapido,
    -- Uso técnico observado
    f.n_conectores_ativos,
    f.n_evse_estimados_ativos,
    f.taxa_conectores_ativos,
    f.taxa_evse_ativos_estimados,
    -- Indicadores de pressão
    f.sessoes_por_evse_instalado,
    f.sessoes_por_conector_instalado,
    f.kwh_por_kw_instalado,
    -- Padrões temporais
    f.pct_fim_semana,
    f.pct_diurno,
    f.pct_horario_laboral,
	f.pct_periodo_descanso,
	f.pct_feriado,
    CASE
        WHEN f.sessoes_mes_ativo >= 500 THEN 'Muito Alta'
        WHEN f.sessoes_mes_ativo >= 200 THEN 'Alta'
        WHEN f.sessoes_mes_ativo >= 50 THEN 'Média'
        ELSE 'Baixa'
    END AS classe_pressao_observada
FROM v30_features_cluster_posto_clean f;

-- -----------------------------------------------------------------------------
-- v51_pressao_posto_spatial
-- Acrescentar a geometria aos indicadores de pressão para a análise espacial
-- 			(usada como uma das views principais no NB05)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v51_pressao_posto_spatial CASCADE;
CREATE OR REPLACE VIEW v51_pressao_posto_spatial AS
SELECT
    p.id_charging_station,
    p.distrito,
    p.municipio,
    p.dtmn,
    p.nuts_3,
    p.nuts_2,
    p.nuts_1,
    -- procura observada
    p.n_sessoes,
    p.energia_total_kwh,
    p.sessoes_mes_ativo,
    p.kwh_mes_ativo,
    -- utilizadores
    p.n_utilizadores_unicos,
    p.n_utilizadores_set_dez_2023,
    p.n_utilizadores_2024,
    p.sessoes_por_utilizador,
    -- oferta instalada
    p.n_evse_instalados,
    p.n_conectores_instalados,
    p.potencia_total_kw,
    p.potencia_max_kw,
    p.tem_dc,
    p.tem_rapido,
    -- pressão / eficiência
    p.sessoes_por_evse_instalado,
    p.sessoes_por_conector_instalado,
    p.kwh_por_kw_instalado,
    -- padrões temporais
    p.pct_fim_semana,
    p.pct_diurno,
    p.pct_periodo_descanso,
	p.pct_feriado,
    p.pct_horario_laboral,
    -- classe de pressão
    p.classe_pressao_observada,
    -- geometria
    o.geom
FROM v50_pressao_posto p
INNER JOIN v20_oferta_posto o
    ON p.id_charging_station = o.id_charging_station;

-- -----------------------------------------------------------------------------
-- v51_postos_sem_procura
-- Identificar os postos instalados sem procura observada no período analisado
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v51_postos_sem_procura CASCADE;
CREATE OR REPLACE VIEW v51_postos_sem_procura AS
SELECT
    o.*
FROM v20_oferta_posto o
LEFT JOIN v14_procura_posto_clean p
    ON o.id_charging_station = p.id_charging_station
WHERE p.id_charging_station IS NULL;


/* =============================================================================
 * 			 Contexto funcional e territorial
 * ============================================================================= 
 */
-- -----------------------------------------------------------------------------
-- v60_facilities_posto
-- Resumir as categorias das facilities associadas a cada posto de carregamento
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v60_facilities_posto CASCADE;
CREATE OR REPLACE VIEW v60_facilities_posto AS
SELECT
    id_charging_station,
    MAX(CASE WHEN facility = 'PARKING_LOT' THEN 1 ELSE 0 END) AS tem_parking_lot,
    MAX(CASE WHEN facility = 'SUPERMARKET' THEN 1 ELSE 0 END) AS tem_supermarket,
    MAX(CASE WHEN facility = 'FUEL_STATION' THEN 1 ELSE 0 END) AS tem_fuelstation,
    MAX(CASE WHEN facility = 'RESTAURANT' THEN 1 ELSE 0 END) AS tem_restaurant,
    MAX(CASE WHEN facility = 'HOTEL' THEN 1 ELSE 0 END) AS tem_hotel,
    MAX(CASE WHEN facility = 'CAFE' THEN 1 ELSE 0 END) AS tem_cafe,
    MAX(CASE WHEN facility = 'NATURE' THEN 1 ELSE 0 END) AS tem_nature,
    MAX(CASE WHEN facility = 'MALL' THEN 1 ELSE 0 END) AS tem_mall,
    MAX(CASE WHEN facility = 'BUS_STOP' THEN 1 ELSE 0 END) AS tem_bus_stop,
    MAX(CASE WHEN facility = 'SPORT' THEN 1 ELSE 0 END) AS tem_sport,
    MAX(CASE WHEN facility = 'RECREATION_AREA' THEN 1 ELSE 0 END) AS tem_recreation_area,
    MAX(CASE WHEN facility = 'TRAIN_STATION' THEN 1 ELSE 0 END) AS tem_train_station,
    MAX(CASE WHEN facility = 'BIKE_SHARING' THEN 1 ELSE 0 END) AS tem_bike_sharing,
    MAX(CASE WHEN facility = 'CARPOOL_PARKING' THEN 1 ELSE 0 END) AS tem_carpool_parking,
    MAX(CASE WHEN facility = 'WIFI' THEN 1 ELSE 0 END) AS tem_wifi,
    MAX(CASE WHEN facility = 'TAXI_STAND' THEN 1 ELSE 0 END) AS tem_taxi_stand,
    MAX(CASE WHEN facility = 'MUSEUM' THEN 1 ELSE 0 END) AS tem_museum,
    MAX(CASE WHEN facility = 'METRO_STATION' THEN 1 ELSE 0 END) AS tem_metro_station,
    MAX(CASE WHEN facility = 'TRAM_STOP' THEN 1 ELSE 0 END) AS tem_tram_stop
FROM local_de_carregamento
GROUP BY id_charging_station;

-- -----------------------------------------------------------------------------
-- v61_parking_posto
-- Resumir as características de estacionamento associadas a cada posto
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v61_parking_posto CASCADE;
CREATE OR REPLACE VIEW v61_parking_posto AS
SELECT
    id_charging_station,
    MAX(parking_type) AS parking_type
FROM local_de_carregamento
GROUP BY id_charging_station;


-- ------------------------------------------------------------------------------------------------
-- v63_contexto_concelho
-- Indicadores territoriais relativos à infraestrutura por município
-- (corresponde à view que tinha criado no qgis com o número de postos por 10k (por concelho))
-- ------------------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v63_contexto_concelho CASCADE;
CREATE OR REPLACE VIEW v63_contexto_concelho AS
WITH oferta_concelho AS (
    SELECT
        dtmn,
        COUNT(DISTINCT id_charging_station) AS n_postos,
        SUM(n_evse) AS n_evse,
        SUM(n_conectores) AS n_conectores,
        SUM(potencia_total_kw) AS potencia_total_kw
    FROM v20_oferta_posto
    GROUP BY dtmn)
SELECT
    c.dtmn,
    c.municipio,
    c.distrito,
    c.nuts_3,
    c.nuts_2,
    c.nuts_1,
    c.area_ha,
    c.area_ha / 100.0 AS area_km2,
    c.perimetro_km,
    c.n_freguesias,
    i.codigo_local_residencia AS cod_concelho_ine,
    i.local_de_residencia AS concelho_ine,
    i.hab_total_hm,
    i.hab_total_hm_15_24,
    i.hab_total_hm_25_64,
    i.hab_total_hm_mais_64,
    i.hab_total_h,
    i.hab_total_m,
    i.hab_total_hm::numeric / NULLIF(c.area_ha / 100.0, 0) AS densidade_hab_km2,
    i.hab_total_hm_15_24::numeric / NULLIF(i.hab_total_hm, 0) AS pct_15_24,
    i.hab_total_hm_25_64::numeric / NULLIF(i.hab_total_hm, 0) AS pct_25_64,
    i.hab_total_hm_mais_64::numeric / NULLIF(i.hab_total_hm, 0) AS pct_mais_64,
    COALESCE(o.n_postos, 0) AS n_postos,
    COALESCE(o.n_evse, 0) AS n_evse,
    COALESCE(o.n_conectores, 0) AS n_conectores,
    COALESCE(o.potencia_total_kw, 0) AS potencia_total_kw,
    COALESCE(o.n_postos, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 1000 AS postos_por_1000_hab,
    COALESCE(o.n_postos, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 10000 AS postos_por_10000_hab,
    COALESCE(o.n_evse, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 1000 AS evse_por_1000_hab,
    COALESCE(o.n_evse, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 10000 AS evse_por_10000_hab,
    COALESCE(o.n_conectores, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 1000 AS conectores_por_1000_hab,
    COALESCE(o.n_conectores, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 10000 AS conectores_por_10000_hab,
    COALESCE(o.potencia_total_kw, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 1000 AS kw_por_1000_hab,
    COALESCE(o.potencia_total_kw, 0)::numeric / NULLIF(i.hab_total_hm, 0) * 10000 AS kw_por_10000_hab
FROM caop_2024 c
LEFT JOIN ine_populacao_2021 i
    ON c.dtmn = LPAD(i.codigo_local_residencia, 4, '0')
LEFT JOIN oferta_concelho o
    ON c.dtmn = o.dtmn
WHERE c.nuts_1 = 'Continente';

-- ---------------------------------------------------------------------------------------------------------------
-- mv65_cos2018_posto
-- Materializa a associação espacial entre postos e classes COS2018 - acelerar as execução de consultas repetidas
-- ---------------------------------------------------------------------------------------------------------------
-- MATERIALIZED VIEW permite gaurdar fisicamente o resultado e reduzindo o custo
-- 		de consultas repetidas — especialmente útil em operações espaciais pesadas, como
-- 		a associação dos postos à COS2018 - são operações pesadas para o SGBD
DROP MATERIALIZED VIEW IF EXISTS mv65_cos2018_posto CASCADE;
CREATE MATERIALIZED VIEW mv65_cos2018_posto AS
SELECT
    p.id_charging_station,
    p.dtmn,
    p.municipio,
    p.distrito,
    p.nuts_3,
    p.nuts_2,
    p.nuts_1,
    c.cos18n1_c,
    c.cos18n1_l,
    c.cos18n2_c,
    c.cos18n2_l,
    c.cos18n3_c,
    c.cos18n3_l,
    c.cos18n4_c,
    c.cos18n4_l,
    c.metodo_atribuicao,
    c.distancia_cos,
    p.geom
FROM v20_oferta_posto p
LEFT JOIN LATERAL (
    SELECT
        x.cos18n1_c,
        x.cos18n1_l,
        x.cos18n2_c,
        x.cos18n2_l,
        x.cos18n3_c,
        x.cos18n3_l,
        x.cos18n4_c,
        x.cos18n4_l,
        CASE
            WHEN ST_Covers(x.geom, p.geom)
                THEN 'cobertura'
            ELSE 'proximidade'
        END AS metodo_atribuicao,
        ST_Distance(x.geom, p.geom) AS distancia_cos
    FROM cos_2018 x
    WHERE ST_DWithin(x.geom, p.geom, 20)
    ORDER BY
        CASE
            WHEN ST_Covers(x.geom, p.geom) THEN 0
            ELSE 1
        END,
        ST_Distance(x.geom, p.geom),
        x._id
    LIMIT 1
) c ON TRUE
WHERE p.nuts_1 = 'Continente';
COMMENT ON MATERIALIZED VIEW mv65_cos2018_posto IS
'Associação dos postos à COS2018 pelo polígono mais próximo até 20 metros, usando ST_DWithin e ST_Distance.';
COMMENT ON MATERIALIZED VIEW mv65_cos2018_posto IS
'Associação dos postos à COS2018 pelo polígono mais próximo num raio máximo de 20 metros. Requer geometrias num SRID projetado com unidade em metros.';
CREATE UNIQUE INDEX idx_mv65_cos2018_posto_id
ON mv65_cos2018_posto (id_charging_station);
CREATE INDEX idx_mv65_cos2018_posto_geom
ON mv65_cos2018_posto
USING GIST (geom);
ANALYZE mv65_cos2018_posto;
REFRESH MATERIALIZED VIEW mv65_cos2018_posto;

-- --------------------------------------------------------------------------------------------
-- v65_cos2018_posto
-- Associação final entre postos e classes COS2018 a partir da materialized view
-- --------------------------------------------------------------------------------------------
DROP VIEW IF EXISTS v65_cos2018_posto CASCADE;
CREATE OR REPLACE VIEW v65_cos2018_posto AS
SELECT *
FROM mv65_cos2018_posto;

-- -----------------------------------------------------------------------------
-- v66_posto_rede_viaria_proxima
-- Associar cada posto ao segmento/categoria de rede viária mais próximo
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS v66_posto_rede_viaria_proxima CASCADE;
CREATE OR REPLACE VIEW v66_posto_rede_viaria_proxima AS
SELECT
    p.id_charging_station,
    p.dtmn,
    p.municipio,
    p.distrito,
    p.nuts_3,
    p.nuts_2,
    p.nuts_1,
    r.road_number,
    r.categoria,
    r.estado,
    r.gestao,
    r.n_vias,
    ST_Distance(p.geom, r.geom) AS dist_via_m,
    p.geom
FROM v20_oferta_posto p
LEFT JOIN LATERAL (
    SELECT
        r.*
    FROM rede_rodoviaria r
    ORDER BY p.geom <-> r.geom
    LIMIT 1
) r ON TRUE
WHERE p.nuts_1 = 'Continente';


/* =============================================================================
 * 			Análise de sensibilidade — exclusão de Lisboa e Porto
 * ============================================================================= 
 */
-- -----------------------------------------------------------------------------
-- v10_carregamentos_mes_exlude_LP
-- Repetr a agregação mensal excluindo os distritos de Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v10_carregamentos_mes_exlude_LP AS
SELECT
    mes,
    COUNT(*) AS n_sessoes,
    COUNT(DISTINCT id_charging_station) AS n_postos_ativos,
    COUNT(DISTINCT evse_id_raw) AS n_evse_raw_ativos,
    COUNT(DISTINCT connector_id) AS n_conectores_ativos,
    COUNT(DISTINCT token_uid) AS n_utilizadores,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh,
    /*
     * Calcular a Mediana (percentile_cont(0.5) para obter a mediana
     * 		- útil para a existência de valores demasiado díspares
     * 		- caso o total de valores seja par, faz a interpolação
     */
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_energy) AS energia_mediana_kwh,
    AVG(duracao_calculada_min) AS duracao_media_min,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY duracao_calculada_min) AS duracao_mediana_min,
    SUM(total_cost_excl_vat) AS custo_total,
    AVG(total_cost_excl_vat) AS custo_medio
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <>'Lisboa' AND distrito <> 'Porto'
GROUP BY mes
ORDER BY mes;

-- -----------------------------------------------------------------------------
-- v12_perfil_horario_exclude_LP
-- Calcular o perfil horário excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v12_perfil_horario_exclude_LP AS
SELECT
    hora_inicio,
    COUNT(*) AS n_sessoes,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
GROUP BY hora_inicio
ORDER BY hora_inicio;

-- -----------------------------------------------------------------------------
-- v12_perfil_horario_normalizado_exclude_LP
-- Normalizar o perfil horário excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v12_perfil_horario_normalizado_exclude_LP AS
SELECT
    hora_inicio,
    COUNT(*) AS n_sessoes,
    COUNT(DISTINCT start_date_time::DATE) AS n_dias,
    COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia_hora,
    SUM(total_energy) AS energia_total_kwh,
    SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_hora_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
GROUP BY hora_inicio
ORDER BY hora_inicio;

-- -----------------------------------------------------------------------------
-- v13_perfil_semanal_exclude_LP
-- Calcular o perfil semanal excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v13_perfil_semanal_exclude_LP AS
SELECT
    dia_semana,
    COUNT(*) AS n_sessoes,
    SUM(total_energy) AS energia_total_kwh,
    AVG(total_energy) AS energia_media_kwh
FROM v01_sessoes_validas_clean
WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
GROUP BY dia_semana
ORDER BY dia_semana;

-- -----------------------------------------------------------------------------
-- v13_perfil_semanal_normalizado_without_LP
-- Normalizar o perfil semanal excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v13_perfil_semanal_normalizado_without_LP AS
SELECT
	dia_semana,
	CASE dia_semana
		WHEN 0 THEN 'Sunday'
		WHEN 1 THEN 'Monday'
		WHEN 2 THEN 'Tuesday'
		WHEN 3 THEN 'Wednesday'
		WHEN 4 THEN 'Thursday'
		WHEN 5 THEN 'Friday'
		WHEN 6 THEN 'Saturday'
	END AS dia_semana_nome,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_kwh,
	AVG(total_energy) AS energia_media_por_sessao_kwh
	FROM v01_sessoes_validas_clean
	WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
	GROUP BY dia_semana
	ORDER BY dia_semana;

-- -----------------------------------------------------------------------------
-- v13_weekday_weekend_normalizado_exclude_LP
-- Comparar os dias úteis e os fins de semana excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v13_weekday_weekend_normalizado_exclude_LP AS
SELECT
	CASE
		WHEN fim_semana = 1 THEN 'weekend'
		ELSE 'weekday'
	END AS tipo_dia,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_kwh,
	AVG(total_energy) AS energia_media_por_sessao_kwh
	FROM v01_sessoes_validas_clean
	WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
	GROUP BY fim_semana
	ORDER BY tipo_dia;

-- -----------------------------------------------------------------------------
-- v13_perfil_horario_weekday_weekend_exclude_LP
-- Calcular os perfis horários weekday/weekend excluindo Lisboa e Porto
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v13_perfil_horario_weekday_weekend_exclude_LP AS
SELECT
	hora_inicio,
	CASE
		WHEN fim_semana = 1 THEN 'weekend'
		ELSE 'weekday'
	END AS tipo_dia,
	COUNT(*) AS n_sessoes,
	COUNT(DISTINCT start_date_time::DATE) AS n_dias,
	COUNT(*)::numeric / COUNT(DISTINCT start_date_time::DATE) AS sessoes_media_por_dia_hora,
	SUM(total_energy) AS energia_total_kwh,
	SUM(total_energy)::numeric / COUNT(DISTINCT start_date_time::DATE) AS energia_media_por_dia_hora_kwh
	FROM v01_sessoes_validas_clean
	WHERE mes BETWEEN DATE '2023-02-01' AND DATE '2024-12-01' AND distrito <> 'Lisboa' AND distrito <> 'Porto'
	GROUP BY hora_inicio, fim_semana
	ORDER BY hora_inicio, tipo_dia;
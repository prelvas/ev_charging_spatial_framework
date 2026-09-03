# na raiz do projeto
python -m venv .venv
source .venv/bin/activate


# instalar biblioteca(s)
pip install pandas psycopg2
# ou
pip install psycopg2-binary
pip install geopandas shapely psycopg2-binary

# criar o ficheiro com os requirements - biblotecas instaladas
pip freeze > requirements.txt

# para instalar os requirements
pip install -r requirements.txt


# para usar Jupyter - após iniciar o venv (activate)
pip install ipykernel
# opcional
python -m ipykernel install --user --name=venv --display-name "Python (venv)"

# se após instalar o requirements.txt o Jupyter não compilar, executar o comando seguinte
python -m ipykernel install --user --name=venv

# estrutura do projeto
projeto/
│
├── .venv/                  - ambiente virtual
├── db/                     - scripts Python para comunicação com db (omitido) 
│   ├── config.py
│   └── ...
├── libs/                     - funções internas (omitido) 
│   ├── maps_utils.py
│   └── ...
├── scripts/                - scripts Python para carregar dados (ingestion database)
│   ├── upload_postos.py
│   ├── upload_carregamentos.py
│   └── ...
├── data/                  - CSVs, shapefiles, etc.
│   ├── postos.csv         - omitido 
│   ├── carregamentos.csv. - omitido
│   ├── COS2018.gpkg        
│   ├── CAOP2024.shp      
│   ├── INE.csv
│   ├── rede_rodoviaria.shp          
│   └── ...
├── sql/                    - scripts SQL para criação de tabelas
│   ├── create_postos.sql
│   └── ...
├── requirements.txt        - dependências do projeto
└── README.md               - documentação opcional

DROP TABLE IF EXISTS ACH_DATA;

CREATE TABLE ACH_DATA (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP, 
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
md5 varchar(32) NOT NULL,
id varchar(32), 
function integer, 
source integer,
organism integer,
organism_group integer
);
CREATE INDEX DATA_ID ON ACH_DATA (id);
CREATE INDEX DATA_organism ON ACH_DATA (organism);
CREATE INDEX DATA_organismGroup ON ACH_DATA (organism_group); 
CREATE INDEX DATA_md5 ON ACH_DATA (md5);
CREATE INDEX DATA_md5_source ON ACH_DATA (source,md5);
CREATE INDEX DATA_function ON ACH_DATA (function);


DROP TABLE IF EXISTS ACH_FUNCTIONS;

CREATE TABLE ACH_FUNCTIONS (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
function text
);
CREATE INDEX FUNCTIONS_function ON ACH_FUNCTIONS (function);


DROP TABLE IF EXISTS ACH_SOURCES;

CREATE TABLE ACH_SOURCES (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
name text,
source text,
ids integer,
md5s integer,
functions integer,
organisms integer,
email text,
type text,
url text,
link text
);
CREATE INDEX SOURCES_name ON ACH_SOURCES (name);


DROP TABLE IF EXISTS ACH_ORGANISMS;

CREATE TABLE ACH_ORGANISMS (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP, 
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
name text NOT NULL,
tax_domain text,
tax_kingdom text,
tax_phylum text,
tax_class text,
tax_order text,
tax_family text,
tax_genus text,
tax_species text,
taxonomy text,
ncbi_tax_id integer,
organism_group integer
);
CREATE INDEX ORGANISMS_name ON ACH_ORGANISMS (name);
CREATE INDEX ORGANISMS_domain ON ACH_ORGANISMS (tax_domain);

DROP TABLE IF EXISTS ACH_ID2CONTIG;

CREATE TABLE ACH_ID2CONTIG (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
id varchar(32),
contigid varchar(32),
contiglength integer,
strand integer,
low integer,
high integer,
md5 varchar(32)
);
CREATE INDEX ID2CONTIG_ID ON ACH_ID2CONTIG (id);
CREATE INDEX ID2CONTIG_md5 ON ACH_ID2CONTIG (md5);

DROP TABLE IF EXISTS ACH_OLD_SEED;

CREATE TABLE ACH_OLD_SEED (
_id SERIAL PRIMARY KEY,                                                   
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP, 
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
md5 varchar(32) NOT NULL,
id varchar(32),
xxx varchar(16),
function varchar(500), 
source integer,
organism integer,
organism_group integer
);
CREATE INDEX OLD_SEED_ID ON ACH_OLD_SEED (id);
CREATE INDEX OLD_SEED_organismGroup ON ACH_OLD_SEED (organism_group); 
CREATE INDEX OLD_SEED_md5 ON ACH_OLD_SEED (md5);
CREATE INDEX OLD_SEED_xxx ON ACH_OLD_SEED (xxx);
CREATE INDEX OLD_SEED_function ON ACH_OLD_SEED (function);


DROP TABLE IF EXISTS ACH_COUNTS;

CREATE TABLE ACH_COUNTS (
_id SERIAL PRIMARY KEY,
_mtime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
_ctime timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
type text,
count integer
);
CREATE INDEX COUNTS_type ON ACH_COUNTS (type);

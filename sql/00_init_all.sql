:ON ERROR EXIT

PRINT 'Starting HotelDatabase initialization...';

:r /sql/01_create_database.sql
:r /sql/02_create_tables.sql
:r /sql/03_constraints.sql
:r /sql/04_indexes.sql
:r /sql/05_views.sql
:r /sql/06_security.sql
:r /sql/07_triggers.sql
:r /sql/08_stored_procedures.sql
:r /sql/09_seed_data.sql

PRINT 'HotelDatabase initialization completed.';



## Step0 - create a database

Build an UTF-8 database. As ilustration we are using standard PostgreSQL user,

```
cd socKer-complete  # the git clone folder
psql -h localhost -U postgres < src/build0-db.sql
```
Now you can use the `testdb` database. Change [build0-db.sql](build0-db.sql) to preffered name, or use your production name (instead `testdb`) in the next steps and terminal commands.

##  Step1 - create schema and ENUM

The SQL script [build1-sch.sql](build1-sch.sql) builds the `socker` SQL SCHEMA with `socker.enum_item` table.

```
cd socKer-complete  # the git clone folder
ln -sf $PWD/data/enum.csv /tmp/pgstd_socKer_file1.csv  # to connect the file_fdw SQL extension.
sudo chown -h postgres:postgres /tmp/pgstd_socKer_file1.csv
psql -h localhost -U postgres testdb < src/build1-sch.sql
```
The SQL script also INSERTs contents from [enum.csv](../data/enum.csv).

##  Step2 - main tables and constraints

The SQL script [build2-main.sql](build2-main.sql) builds the main tables and add main constrains.

```
psql -h localhost -U postgres testdb < src/build2-main.sql
```

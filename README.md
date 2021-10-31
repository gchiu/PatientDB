# revolt-db

**Firebird**

Download the server binary for Windows https://github.com/FirebirdSQL/firebird/releases/download/v4.0.0/Firebird-4.0.0.2496-1-x64.exe

Install with default settings

Firebird ODBC

https://sourceforge.net/projects/firebird/files/firebird-ODBC-driver/2.0.5-Release/Firebird_ODBC_2.0.5.156_x64.exe/download

Install with default settings

Create the database using the Firebird commandline tool isql

https://firebirdsql.org/manual/qsg10-creating.html

In my install it was found here C:\Program Files\Firebird\Firebird_4_0>isql.exe

  C:\Program Files\Firebird\Firebird_4_0>isql  
  Use CONNECT or CREATE DATABASE to specify a database  
  SQL> CREATE DATABASE 'd:\patients.fdb' page_size 8192  
  CON> user 'SYSDBA' password 'masterkey';  
  SQL> QUIT; 

Create odbc connection named patients

Create the ODBC user

Stop the server service from services/standard tab
And from an elevated command prompt.  Choose a strong password instead of 'masterkey'

    D:\>C:isql -user sysdba PATIENTS.FDB  
    Database: PATIENTS.FDB, User: SYSDBA  
    SQL> CREATE USER SYSDBA PASSWORD 'masterkey';  
    SQL> QUIT;  

Restart the server service

Create odbc connection named patients and test, it should work

Download Rebol eg. from https://metaeducation.s3.amazonaws.com/travis-builds/0.3.40/r3-f148260.exe

and save it as r3.exe in the same directory as the patients.fdb files

save the test odbc script to confirm it's all working

    >> write %odbc-test.reb read https://raw.githubusercontent.com/metaeducation/rebol-odbc/master/tests/odbc-test.reb  
    == #[port! [...] [...]]

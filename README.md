# SQL_JPK_WB
SQL program to generate JPK_WB (Standard Audit File-Tax bank statement) file with use of SSIS package to load data into database. 

As an input, SSIS takes 2 files: first one "podmiot1.txt" (data of an account owner) and IBAN.txt (containing records of bank statement). 
SQL procedure generate XML file as an output in path passed as an argument. 

In SQL procedure, you can specify a date range from which you want to generate XML file.

Database architecture:

![obraz](https://user-images.githubusercontent.com/66008982/167425491-a8814d93-4bbe-4f2c-9b72-3db39a6306ef.png)


SSIS package:

  Control Flow:
  
  ![obraz](https://user-images.githubusercontent.com/66008982/167425515-8fa570f8-b0fc-46a6-ad9c-24ffff7a14ee.png)

  Data Flow:
  
  ![obraz](https://user-images.githubusercontent.com/66008982/167425531-02bf62ab-8dae-4747-8917-ba3ab658e0f2.png)


All data in example files are generated and do not belong to anyone. 

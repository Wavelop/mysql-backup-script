# mysql-backup-script

This is a simple shell script for backup MySQL database and store it in a FTP connection.
In this guide, we will make a simple bash script, which takes the backup of MySQL database and store in a FTP server. This script will also remove older backups from server for free the space.
You can find the full code in mysql-backup.sh file in this repo.

### Index

- [Mysql dump command](#dump)
- [Upload file to server](#upload)
- [Delete older file](#delete)
- [Add script to crontab](#crontab)
- [Restore the backup](#restore)

## <a name="dump">Mysql Dump Command</a>

The command to create a mysql backup is **mysqldump**. You can edit the config varibles with your DB configuration to generate the backup.

    #! /bin/bash
    ### MySQL Server Login Info ###
    MUSER="[your_mysql_user]"
    MPASS="[your_mysql_passwor]"
    MHOST="[your_mysql_host]"
    MPORT="[your_mysql_port]"
    DBNAME="[your_mysql_database]"
    MYSQL="$(which mysql)"
    MYSQLDUMP="$(which mysqldump)"
    ### File Info ###
    # Save backup in temp directory before upload to server
    TEMPDIR="[your_bkp_temp_dir]" #Exp: ./bkp_temp
    # Name of bkp file (before the date)
    FILENAME="[your_bkp_file_name_root]" #Exp: my_prj_daily_bkp_
    NOW=$(date +%F)
    #Create and clean temp directory
    [ ! -d "$TEMPDIR" ] && mkdir -p "$TEMPDIR"
    rm -f "$TEMPDIR"/*.*
    # Create bkp
    TFILENAME="$FILENAME""$NOW".sql
    FILE=$TEMPDIR/$TFILENAME
    $MYSQLDUMP -u $MUSER -h $MHOST -P $MPORT  -p$MPASS $DBNAME > $FILE

This is the script to perform the backup:

    $MYSQLDUMP -u $MUSER -h $MHOST -P $MPORT  -p$MPASS $DBNAME > $FILE

And this is an example with clear variables:

    mysqldump -u root -h localhost -P 3306  -proot testdb > bkp_daily_2018-10-10.sql

## <a name="upload">Upload file to server FTP</a>

You have multiple solution to upload a file with ftp in a server.
In this case (for our ftp server connection) we use this solution:

    ### FTP SERVER Login info ###
    FTPU="[your_ftp_username]"
    FTPP="[your_ftp_password]"
    FTPS="[your_ftp_server]"
    DESTDIR="[your_ftp_destination_dir]"
    ftp -n $FTPS <<END_SCRIPT
    quote USER $FTPU
    quote PASS $FTPP
    binary
    put $FILE $DESTDIR/$TFILENAME
    quit
    END_SCRIPT

(`$FILE` and `$TFILENAME` are generated in the step before)  
This open a connection with the FTP server and put the file in the directory you specify.

## <a name="delete">Delete older file</a>

Sometimes it is not necessary to store all the daily backups, the disk space would finish in a short time. One solution is to keep all backups, for example, from the last month (perhaps by doing a separate monthly backup).  
This is a solution, using the date in the name of the backup file, to delete the files in the FTP server.

    listing=`ftp -i -n $FTPS <<EOMYF
    quote USER $FTPU
    quote PASS $FTPP
    binary
    cd $DESTDIR
    ls $FILENAME*
    quit
    EOMYF
    `

This script open the connection to FTP server and return the list of backup names with our base name.

    lista=( $listing )
    # loop over our files
    for ((FNO=0; FNO<${#lista[@]}; FNO+=9));do
        # month (element 5), day (element 6) and filename (element 8)
        # filename
        f=${lista[`expr $FNO+8`]}
        IFS='_' read -r -a arrayF <<< "$f"
        IFS='.' read -r -a arrayD <<< "${arrayF[2]}"
        # Split name and get date
        d=${arrayD[0]}
        DAY=$(date -d "$d" +%Y-%m-%d)
        diff=$(( ($(date -d $NOW +%s) - $(date -d $DAY +%s) )/(60*60*24) ))
        # Remove older file
        if [[ $NDAYS -lt $diff ]];
        then
            ftp -n $FTPS <<END_SCRIPT
            quote USER $FTPU
            quote PASS $FTPP
            binary
            cd $DESTDIR
            delete $f
            quit
    END_SCRIPT
    fi
    done

For each file get the date from the name and if it's older then `$NDAYS` connect to FTP server and delete the file.

## <a name="crontab">Add script to crontab</a>

`crontab` is a Linux command used to schedule operations (**jobs**) using the `cron daemon`.
The `cron daemon` reads the `crontab` file and follows the operations set there (**cronjob**) at the specified time and **completely automatically**.

### Basic commands

**List**

    crontab -l

Show the content of the crontab.

**Remove**

    crontab -r

Remove all crontab jobs.

**Edit**

    crontab -e

Open a vim editor and let you to modify your crontab config.

### Schedule a job

In our crontab we can insert all jobs we want. We have to specify only the execution date and the job to execute.

This is the format to insert a new activities

    [minutes] [hour] [month day] [month] [week day] [path to script]

For example:

    00 00 * * * /usr/script/mysql-backup.sh

This line execute our mysql backup script every day at 00:00 (midnight).

**All**  
With the (**\***) we specify all the possibility

    00 00 * * * /usr/script/mysql-backup.sh

For example this is every day at 00:00.

**Repeater**  
With the (**/**) we specify the repetition of the task

    */5 00 * * * /usr/script/mysql-backup.sh

This example run the script every 5 minutes

**Range**  
With the (**-**) we specify the range

    00 9 1-4 * * /usr/script/mysql-backup.sh

This example run the script at 9:00 on the first 4 days at every month.

**List**  
With the (**,**) we specify a list

    00 9 * 6,12 * /usr/script/mysql-backup.sh

This example run the script every day at 9:00 on the month of june (6) and december (12).

**Shortcat**

- **@reboot** Run job at system reboot
- **@yearly** Run job one times in a year [0 0 1 1 *]
- **@annually** Run job one times in a year [0 0 1 1 *]
- **@monthly** Run job every months [0 0 1 * *]
- **@weekly** Run job every weeks [0 0 * * 0]
- **@daily** Run job every day [0 0 * * *]
- **@midnight** Run job every day [0 0 * * *]
- **@hourly** Run job every hour [0 * * * *]

### Schedule our job

Finaly we can schedule our mysql script in crontab.  
We decide to run every day. This is the final command:

    @daily /usr/script/mysql-backup.sh

## <a name="restore">Restore the backup</a>

Finaly if you need to restore a mysql backup (hope for test, not for revert production stuff) we need to identify our correct backup and retrive from FTP server.  
Once you have your file you can run:

    mysql -u [username] -p [DB name] < [file.sql]

To different host:

    mysql -h [host] -u [username] -p [DB name] < [file.sql]

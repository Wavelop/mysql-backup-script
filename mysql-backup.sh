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
### FTP SERVER Login info ###
FTPU="[your_ftp_username]"
FTPP="[your_ftp_password]"
FTPS="[your_ftp_server]"
DESTDIR="[your_ftp_destination_dir]"
### DELETE OLD BKP ###
## Number of days to keep backup copy
NDAYS=[your_day_to_store]

#Create and clean temp directory
[ ! -d "$TEMPDIR" ] && mkdir -p "$TEMPDIR"
rm -f "$TEMPDIR"/*.*

#Create bkp
TFILENAME="$FILENAME""$NOW".sql
FILE=$TEMPDIR/$TFILENAME
$MYSQLDUMP -u $MUSER -h $MHOST -P $MPORT  -p$MPASS $DBNAME > $FILE

#Connect to FTP and put the BKP file
ftp -n $FTPS <<END_SCRIPT
quote USER $FTPU
quote PASS $FTPP
binary
put $FILE $DESTDIR/$TFILENAME
quit
END_SCRIPT

# Connect to FTP and get all bkp file name
listing=`ftp -i -n $FTPS <<EOMYF
quote USER $FTPU
quote PASS $FTPP
binary
cd $DESTDIR
ls $FILENAME*
quit
EOMYF
`
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

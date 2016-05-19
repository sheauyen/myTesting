#!/usr/bin/perl
# On SDSC Solaris systems, change the above line to use this path:
# #!/usr/local/bin/perl5.8

$Version="install.pl version 3.x, last updated Dec 3, 2007";

# This script performs all the steps required to do a basic full
# Postgres MCAT-enabled SRB installation, starting with the
# distribution files, on Linux, Solaris, AIX, or Mac OS X (or a subset,
# see SUBSET paragraph). It configures 
# and builds Postgres, Postgres-ODBC, and SRB, initializes the database,
# ingests the MCAT tables, updates configuration files, brings up the
# system, provides access to local disk space as an SRB resource, and
# configures the current user with access; the manual steps described
# in README.MCAT.INSTALL.  This can be used directly by those wanting
# to install SRB for basic testing and operation, and can illustrate
# what is needed for those doing more elaborate installations.

# This script sets everything up to run the servers and the SRB client
# programs from the current user login.

# Edit the defines a few lines below here for your installation, and
# then run "./install.pl" (or perhaps "perl install.pl").  It will keep
# track of which steps have been completed and continue where it left
# off, if something goes wrong.

# First you download the SRB from:
# http://www.sdsc.edu/srb/tarfiles/main.html , Postgres from
# http://www.postgresql.org/ , and Postgres odbc from
# http://www.postgresql.org/ftp/odbc/versions/ for example:
# ftp://ftp.postgresql.org/pub/odbc/versions/src/psqlodbc-07.03.0200.tar.gz

# You should move this script and the three .tar[.gz] files to a new
# directory.  By default, this script will install each package under
# this current directory, as well as the SRB storage area (Vault).  If
# you already have unpacked the SRB file, just put this script and the
# .tar[.gz] files above where you unpacked SRB (since this is kept
# in MCAT, that would be cp ../..).

# The total disk space needed for these packages is about 700 MB, at
# least on Linux.  If you run out of disk space while install.pl is
# configuring, building, testing or installing any of the three
# packages, you'll see some errors, most likely something very odd
# looking, as some file writes by the compiler, linker, or some other
# process will fail.

# You can also use this script to start and stop the postgres and SRB
# servers, via ./install.pl start and ./install.pl stop.  There is
# also a ./install.pl ps that lists the postgres and srb processes
# (servers).

# There is also an ./install.pl clean option to remove everything that
# was built and installed (first stopping the the running postgres and
# srb processes).  Use this with caution as it removes the entire
# database, all the srb files, and the compiled software.  But it is
# useful when you want to start over.

# There are also some performance ehancements options available for
# use, if you are running your Postgres MCAT under heavy load (lots of
# srb objects, data updates, and/or users, etc).  Neither of these
# should be run on small databases (these will actually slow it down),
# but both should be run on larger databases (especially if yours is
# getting slower).  One is 'install.pl index' to index the Postgres
# MCAT tables, and it should be run once (anytime after the
# installation).  The other is 'install.pl vacuum' which runs
# 'vacuumdb' to garbage-collect and analyze the PostgreSQL MCAT
# database; and this should be run once in a while (see PostgreSQL
# documentation for recommendations based on your load).  'install.pl 
# vacuum' will stop the SrbServers, run vacuumdb, and then restart
# them so that vacuumdb will not hang.

# There is also a './install.pl zone name' option that sets the
# $YOUR_ZONE parameter and can be used in your install.conf to adjust
# other parameters based on that (see section before the 
# require "install.conf" call).

# While building postgresql you may see an error that Bison as install
# on your system is too old, it needs 1.875 or later.  In our
# experience, this can be safely ignored.  Postgresql seems to work
# fine even with the older Bison, at least for the light testing that
# we typically do.

# SUBSETs of the full installation can be selected, with the following
# options:
#    1) Use an existing Postgres installation.
#       You need to modify the $postgresInstallDir line below to point to
#       the existing postgres installation and set $SubsetMode (below) 
#       to 1.  This script will then skip the steps to build
#       postgres and postgres-odbc and to initialize postgres and 
#       will use the existing one.  It will still attempt to create 
#       the MCAT database so you will need to either use option 2 or 3 below,
#       or change the name of the MCAT DB ($DB_NAME), or drop the old one 
#       if you no longer want it (run the postgres command "dropdb name").
#
#       When in this mode, only the srbservers (not postgres) are started
#       or stopped via the start and stop commands.
#
#       Be sure that your SRB server host is allowed to connect to the
#       postgresql server.  You may need a line like this (with your
#       host IP address) in the data/pg_hba.conf file:
#       host    MCAT  all 132.249.32.192  255.255.255.255   trust
#
#    2) Do everything as in mode 1 but also skip the initialization of
#       the MCAT database.  In this mode, $DB_NAME must match an existing
#       MCAT database name.  More commonly, you'll want to use 3.
#
#       Set $postgresInstallDir line to an existing installation and
#       set $SubsetMode to 2.
#
#    3) Like 2 but also skip ingesting new domains, users, etc.
#       
#       Set $postgresInstallDir line to an existing installation and
#       set $SubsetMode to 3.

# We experimented with trying to use an existing RedHat RPM
# installation of postgres but found too many incompatibilities.  But
# if you have a running postgres, you can set the POSTGRES_PORT
# parameter (a ways below) and this script will then build and run its
# postgres on an alternative port.

$startDir=`pwd`;
chomp($startDir);

# ***********************************************************************

# These are the important settings that you must specify for the installation.
# You must fill in these with the files you have and options you want.
# If you prefer, you can put these settings into a separate file 
# "install.conf" which will be included (perl "require") if it exists;
# settings in "install.conf" will override those defined here:
$SRB_FILE="SRB3.5.0rele_pgp.tar";   # The SRB tar file
                                  # Note: if you have a srb source tree 
                                  # (e.g. via cvs checkout or unpacking the tar
                                  # file) in $SRB_DIR (below), then you should
                                  # set SRB_FILE to "".
$SRB_FILE_ALREADY_DECRYPTED=1;    # Set this to 1 if the SRB Tar file is
                                  # already  decrypted (e.g., you did it 
                                  # manually).
$SRB_DIR="SRB3_5_0";                      # Subdirectory that untar'ing the 
                                  # SRB_FILE creates (if blank, script will
                                  # figure it out).
                                  # Note that this is not a full directory
                                  # path (/something) but the relative path
                                  # under the current directory.
$POSTGRES_FILE="postgresql-8.3.3.tar.gz"; # the postgres release file
$ODBC_FILE="psqlodbc-07.03.0200.tar.gz";  # the odbc release file; DO NOT EDIT,
                                  # as 07.03.0200 is the recommended version.
                                  # As of Februrary 2006 (and for a
                                  # long time before), we have been unable to
                                  # use recent versions of ODBC along
                                  # with iODBC or unixODBC as a "ODBC
                                  # Manager".  There may be some
                                  # incompatibility with how SRB makes
                                  # use of it.  But 7.3.200 seems to
                                  # work fine, even with more recent
                                  # versions of postgresql.
$DB_NAME="MCAT";                  # Name of the Postgres database to create 
                                  # and use as the MCAT database.
$YOUR_ADMIN_NAME="srbAdmin";      # Change this to the name for the srb-admin 
                                  # login acct that you would like to use (this
                                  # can be what ever name you want).
$YOUR_POSTGRES_ADMIN_NAME="$YOUR_ADMIN_NAME"; # Normally the postgres admin is
                                  # the same as the SRB admin username, but you
                                  # can set it to another value if needed,
                                  # e.g.: using an existing postgres.
$YOUR_ADMIN_PW="myadmin";                # Change this to a password you want to use
                                  # for this admin account (this script will
                                  # also change the builtin admin account 
                                  # password to this).  Later, 
                                  # for improved security, you should change
                                  # this value in this script file.
$YOUR_DOMAIN="demo";              # Change this to the SRB domain name you 
                                  # would like to use.
$YOUR_ZONE="A";                   # Change this to the local zone name you
                                  # would like to use.
$RESOURCE_NAME="demoResc";        # Name of the local SRB resource name that
                                  # this SRB server will create and use
$RESOURCE_DIR="$startDir/Vault";  # Subdirectory that will be the resource
                                  # (i.e., the real unix directory that 
                                  # will hold the SRB data files).
$RESOURCE_NAME2="";               # If defined, this is a second resource
                                  # to create.
$RESOURCE_DIR2="$startDir/Vault2";  # Subdirectory that will be the resource
                                    # for the second resource.
$SAFE_MODE="0";                   # Flag for how careful to be with files
                                  # in your home directory: ~/.srb/.MdasEnv,
                                  # ~/.srb/.MdasAuth, and ~/.odbc.ini.

                                  # If 0: (normal case) move existing files to 
                                  # name.old.'datestring', for example ~/.srb/
                                  # .MdasEnv.old.Wed_Sep_24_11:19:17_PDT_2003

                                  # If 1: don't overwrite existing files;
                                  #    If an old one exists and a new one 
                                  #    is needed, quit.

$SRB_PORT="";                     # Change this to some number if you
       # want to run the SRB Server on a different port.  By default
       # (if you leave this blank), the regular port will be used: 5544.


                                  
$SRB_COMMPORTS="";                # Set this to non-blank if you want to
                                  # restrict the tcp/ip ports that are used;
                                  # useful with firewalls (see SRB FAQ).
$SRB_COMMNUM="200";               # Used when SRB_COMMPORTS is set;
                                  # the number of ports; 200 is ususally
                                  # fine and is the default.
$SRB_COMMSTART="20000";           # Used when SRB_COMMPORTS is set;
                                  # the starting port number to use.


$IP_ADDRESS_LOCALHOST="";         # Normally, LEAVE THIS UNSET!
       # Set this to "127.0.0.1", the loopback address, if you want to
       # build and run without network connectivity, for example on a
       # laptop that has no network available.  With this setting,
       # your SRB will not need the network, nor will it be able to
       # use the network.  That is, it can be used for testing or
       # demos but not normal operation.

       # You may need to use this on Mac OS X systems but normally
       # don't on others.  Only set this if the DNS-type commands will
       # not work for you.  That is, if you need to use the IP address
       # of your host instead of having this script run uname and host
       # (see setHostVars).  If you do set this, use either
       # "127.0.0.1" (see above) or use what is normally the actual IP
       # number (for example "192.168.1.103").

# On most systems, the simple host name will resolve to the full
# domain and IP address (see setHostVars() for how this is done).  If
# this does not work on your host (for example, using DHCP in some
# cases), you may be able to solve this by adding an entry in your
# /etc/hosts file with the ip and simple host name, like
# '130.246.76.21 escpc31'.  This associates the short name to that IP
# address.  When the machine is rebooted, if it picks up a new IP
# address, then /etc/hosts would need to be updated, and SRB settings
# may need to be changed too.

$DO_JAVA=0;                       # By default, don't re-build Java stuff
   # since it usually isn't necessary.  Starting with SRB 3.1, the Java
   # Admin Tool uses Jargon and so is pure java and doesn't need to
   # be rebuilt.  The jar files are already included in the release.
   # You don't even need the JDK installed (you need java not javac). 
   # Just cd to MCAT/java and run 'java -jar mcatAdmin.jar'.
# But if you want to rebuild the Java code (Jargon and the Java Admin Tool),
# then set $DO_JAVA=1 .  You may also need specify where javac is, in
# which case add "--enable-jdkhome=<path>" to the line below (see
# the SRB configure script for more information):
$SRB_CONFIGURE_OPTIONS_JAVA="";

# Define the following if you want to create remote zones:
$REMOTE_ZONE="";                  # Remote zone name
$REMOTE_LOCATION="";              # Name to use for the remote Location
$REMOTE_HOST_ADDR="";             # Full DNS name of remote host
$REMOTE_DOMAIN="";                # Remote domain zame
$REMOTE_ADMIN_NAME="";            # Remote SRB admin name (@REMOTE_DOMAIN)
$REMOTE_ADMIN_PW="";              # Remote SRB admin name (@REMOTE_DOMAIN)
                                  # This PW is arbitrary, as the real password
                                  # is kept at the remote domain.  Make this
                                  # long and complicated for added safety.

# This is where install.pl will install the SRB server;
# you can change this if you like:
$SRB_INSTALL_DIR="$startDir/SRBInstall";

# This is the subdirectory into which install.pl will install posgresql and
# you can also change this.
# If you are using a SubsetMode (below), then set this to the
# full path of your existing postgres installation.
$postgresInstallDir = "$startDir/pgsql";

#$SubsetMode=0;   # Set this to 1 to use an existing postgres
                  # Set this to 2 to do 1 and use an existing local MCAT db.
                  # Set this to 3 to do 1 and 2 and skip installing MCAT items.

#$POSTGRES_PORT="5489"; # Normally, leave this unset.  
# But if you have an existing postgres installation that you don't
# want to (or can't) use, you can set this and have this script run a
# postgres an an alternative port.  5432 is their default port so 5489
# is an example alternative port; you can set it to some other
# non-5432 value if you wish.  See additional description near the top.

#$UnsetHost=0;    # Used only for testing at SDSC;
                  # If set, comment out the srbHost value in the .MdasEnv file


# ***********************************************************************

# Check for the 'zone name' command line argument, and if so set the
# $YOUR_ZONE parameter.  This then can be used in the install.conf
# where one could adjust parameters based on the zone (for example: 
# if ($YOUR_ZONE eq "b") { $YOUR_ADMIN_NAME="BAdmin";} ). 
($t1, $t2)=@ARGV;
if ($t1 eq "zone") {
    $YOUR_ZONE=$t2;
}

# include install.conf if it exists, defines like those above will
# override those set above.
if (-e "install.conf") {
    require "install.conf";
}



# You can extend the following SRB configure line with other options
# if you like, but it needs to include the currently defined ones:
$SRB_CONFIGURE_OPTIONS="--enable-installdir=$SRB_INSTALL_DIR --enable-psgmcat --enable-psghome=$postgresInstallDir";

# If the SRB_COMMPORTS option has been selected (for firewall
# situations), add in some additional options:
if ($SRB_COMMPORTS) {
    $SRB_CONFIGURE_OPTIONS=$SRB_CONFIGURE_OPTIONS . 
	" --enable-commports" .
	" --enable-commstart=" . $SRB_COMMSTART .
	" --enable-commnum=" . $SRB_COMMNUM ;
}

$postgresTarFile = $POSTGRES_FILE;
if (rindex($POSTGRES_FILE,"gz") gt 0) {
    $postgresTarFile = substr($POSTGRES_FILE,0,-3);
}
$postgresDir=substr($postgresTarFile,0,-4);

$postgresBin = "$postgresInstallDir/bin";
$postgresData = "$postgresInstallDir/data";

if ($SubsetMode lt "1") {
    $createDbOpts="";
}
else {
    # Need to specify the Username when using an existing postgres.
    # You may need to add -W so that it will prompt for a password.
    # You will need to add -h hostname.domain here if postgres is remote.
    $createDbOpts="-U $YOUR_POSTGRES_ADMIN_NAME";
}

# You can change the name of this state file if you like.
# If you want to redo the installation steps, you can remove the stateFile.
$stateFile="install.state";
$state=0;     # Major state/steps: 
              #  A - build and install postgres
              #  B - build and install odbc
              #  C - build srb and srb-mcat
              #  D - configure and run postgres server, create db
              #  E - create and test the MCAT database
              #  F - create local settings, user config, and start SRB
              #  G - do zones: rename local zone, and maybe create remote zones
$subState=0;  # Substep within the major state, 1 thru n

$fullStateFile = "$startDir/$stateFile";

if (!$SRB_FILE) {
    if (! -d "$startDir/$SRB_DIR") {
	usage();
	die("SRB_FILE not set and SRB_DIR ($startDir/$SRB_DIR) does not exist");
    }
}

if (!$YOUR_ADMIN_PW) {
    usage();
    die("YOUR_ADMIN_PW (admin password) is not set");
}

$uid=$<;
if ($uid eq "0") {
    print "This script should not be run as root.\n";
    print "Postgres will not install as root\n";
    print "and the SRB should be run as a non-root user\n";
    die("Running as root");
}

# Needed for Postgres commands:
$ENV{'PGDATA'}="$postgresData";
$oldPath=$ENV{'PATH'};
$ENV{'PATH'}="$postgresBin:$oldPath";
$oldLibPath=$ENV{'LD_LIBRARY_PATH'};  
if (!$oldLibPath) {
#   create LD_LIBRARY_PATH to have postgres
    $ENV{'LD_LIBRARY_PATH'}="$postgresInstallDir/lib";  
}
else {
#   or add it to LD_LIBRARY_PATH (may have GSI libraries defined, for example)
    $ENV{'LD_LIBRARY_PATH'}="$oldLibPath:$postgresInstallDir/lib";
}

# used later for Mac OS X-specific stuff (Darwin)
$thisOS=`uname -s`;
chomp($thisOS);
$gmake="gmake";
$psOptions="-el";
if ($thisOS eq "Darwin") {
# this gmake alias is needed for SRB 3.3.1 and before, so leaving it for now:
    $gmake="alias gmake=make\ngmake";
    $psOptions="-ax";
    $thisProcessorType=`uname -p`;
    $intel=0;
    if (index($thisProcessorType,"386")>=0) {
	$intel=1;
    }
}
else {
# On non-Mac OSes, test for gmake the way post 3.3.1 SRB configure does 
    `$gmake -v`;
    if ($?!=0) {       # No gmake
        $gmake="make"; # Assume gmake is installed as make
    }
}
if ($thisOS eq "SunOS") {
    $psOptions="-ef";
}

# Also on OS X, check and possibly increase the stack size from 512K to 2MB
if ($thisOS eq "Darwin" and !$intel) {
    $stackLimit = getStackLimit();
    if ($stackLimit < 1800000) {
        print "Your current stack size limit is $stackLimit\n";
        print "This is too small for many of the SRB commands\n";
        print "Increasing stack size limit\n";
        setStackLimit(2000000);
        $stackLimit = getStackLimit();
        print "The stack size limit for this process (and children) is now $stackLimit\n";
        print "You will need it set it for your shell.\n";
        print "For tcsh would be 'limit stacksize 2000'\n";
    }
}

setHostVars(); # set a few host-specific variables

$srbDone=0;
readState();

setSRB_DIR();  # if not set and available, set $SRB_DIR


if ($state eq "A" or $state eq "B" or $state eq "C") {
    $postmaster=`ps $psOptions | grep postmas | grep -v grep`;
    if ($postmaster) {
	if ($SubsetMode lt "1") {
	    if (!$POSTGRES_PORT) {
	       print "There is another postgres already running on this host and";
	       print " this script is not configured to use (or ignore) an existing one.\n";
	       die("Aborting, cannot install a second postgres system");
	    }
	    else {
	       print "There is another postgres already running, but this\n";
               print "script will run another on an alternative port.\n";
	    }
	}
    }
}

($arg1)=@ARGV;

if ($arg1 eq "stop") {
    stopServers();
    die ("Done");
}
if ($arg1 eq "clean") {
    print "Do you really want to stop processes and remove the entire\n";
    print "installation; everything that was built with install.pl?\n";
    printf("Enter yes to proceed:");
    $cmd=<STDIN>;
    chomp($cmd);
    if ($cmd ne "yes") {
	die("Aborted by user");
    }
    stopServers();
    runCmdNoLog(1, "chmod u+x  SRBInstall/data/CVS");

    print "The following commands are about to be run:\n";
    print "   rm -rf pgsql\n";
    print "   rm -rf $postgresDir\n";
    print "   rm -rf $RESOURCE_DIR\n";
    print "   rm -rf $RESOURCE_DIR2\n";
    print "   rm -f install*.log\n";
    print "   rm -rf SRBInstall\n";
    print "   rm -f install.state\n";
    printf("Enter yes (again) to do so and remove these directories:");
    $cmd=<STDIN>;
    chomp($cmd);
    if ($cmd ne "yes") {
	die("Aborted by user");
    }
    runCmdNoLog(0, "rm -rf pgsql");
    runCmdNoLog(0, "rm -rf $postgresDir");
    runCmdNoLog(0, "rm -rf $RESOURCE_DIR");
    runCmdNoLog(0, "rm -rf $RESOURCE_DIR2");
    runCmdNoLog(0, "rm -f install*.log");
    runCmdNoLog(0, "rm -rf SRBInstall");
    runCmdNoLog(0, "rm -f install.state");

    print "The following command is about to be run:\n";
    print "   rm -rf $SRB_DIR\n";
    printf("Enter yes (one more time) to do so and remove this directory too:");
    $cmd=<STDIN>;
    chomp($cmd);
    if ($cmd ne "yes") {
	die("Aborted by user");
    }
    runCmdNoLog(0, "rm -rf $SRB_DIR");

    die("Postgres and SRB installation removed");
}
if ($arg1 eq "start") {
    $Servers = "";
    if ($SubsetMode lt "1") {
	runCmdNoLog(0, "$postgresBin/pg_ctl start -o '-i' -l $postgresData/pgsql.log");
	$Servers = "Postgres";
    }
    if ($srbDone eq "1") {
    # have completed SRB installation, start it too
	print "chdir'ing to: $SRB_INSTALL_DIR/bin\n";
	chdir "$SRB_INSTALL_DIR/bin";
	print "sleeping a second\n";
	sleep 1; # postgres sometimes needs a little time to setup
	runCmdNoLog(0, "./runsrb");
	runCmdNoLog(0, "ps $psOptions | grep srb | grep -v grep");
	print "If the srb server is running OK, you should see srbMaster and srbServer here:\n";
	print $cmdStdout;
	if ($Servers) {
	    $Servers = $Servers . " and SRB";
	}
	else {
	    $Servers = $Servers . "SRB";
	}
	print "chdir'ing to: ../..\n";
	chdir "../..";
    }
    die("Done starting " . $Servers . " servers");
}

if ($arg1 eq "ps") {
    $srb=`ps $psOptions | grep srb | grep -v grep`;
    print "Running srb server processes:\n";
    print $srb;
    $post=`ps $psOptions | grep post | grep -v grep`;
    print "Running postgres server processes:\n";
    print $post;
    die("Done listing processes");
}

if ($arg1 eq "vacuum" or $arg1 eq "v")  {
    stopSrbServers();  # to avoid vacuumdb hanging on a semaphore
    runCmdNoLog(0, "$postgresBin/vacuumdb -f -z $DB_NAME");
    print $cmdStdout;
    startSrbServers();
    die("Done running postgresql vacuumdb");
}

if ($arg1 eq "index" or $arg1 eq "i")  {
    print "chdir'ing to: $SRB_DIR/MCAT/data\n";
    chdir "$SRB_DIR/MCAT/data" || die "Can't chdir to $SRB_DIR/MCAT/data";
    if ($thisOS eq "SunOS" or $thisOS eq "AIX" or $thisOS eq "HP-UX") {
	runCmdNoLog(0,"$postgresInstallDir/bin/psql $DB_NAME < catalog.index.psg > ../../../installPostgresqlIndexing.log 2>&1");
    }
    else {
	runCmdNoLog(0,"$postgresInstallDir/bin/psql $DB_NAME < catalog.index.psg >& ../../../installPostgresqlIndexing.log");
    }
    print "The following is the tail of index log (installPostgresqlIndexing.log):\n";
    $tail = `tail ../../../installPostgresqlIndexing.log`;
    print $tail;
    die("Done indexing postgresql MCAT database");
}

if ($state eq "A") {
    buildPostgres();
}

if ($state eq "B") {
    buildOdbc();
}

if ($state eq "C") {
    buildSrb();
}

if ($state eq "D") {
    runPostgres();
}

if ($state eq "E") {
    installMcatDB();
}

if ($state eq "F") {
    createLocalSettings();
}

if ($state eq "G") {
    doZones();
}

print "Some examples for testing and learning about the SRB are at:\n";
print "http://www.sdsc.edu/srb/Edinburgh-Tutorials-May-2004/scmds.txt .\n";
print "If your MCAT becomes slow, see index and vacuum options (top of script)\n";
print "To use the SRB Scommands set your path to include the binaries:\n";
print "set path=($startDir/$SRB_DIR/utilities/bin \$path)\n";
print "Then Sinit, Sls, Sput, Sexit, etc should work.\n";
print "To stop the the postgres and srb servers, run 'install.pl stop'\n";
print "To restart the postgres and srb servers, run 'install.pl start'\n";
print "To show the postgres and srb server processes, run 'install.pl ps'\n";
print "For man pages (csh): alias Sman 'man -M $startDir/$SRB_DIR/utilities/man'\n";
print "All done\n";

# set up $hostName and $hostFullNetName and $hostFullNetAddr
sub setHostVars() {
    if ($IP_ADDRESS_LOCALHOST) {
	$hostName = $IP_ADDRESS_LOCALHOST;
	$hostFullNetName = $IP_ADDRESS_LOCALHOST;
	$hostFullNetAddr = $IP_ADDRESS_LOCALHOST;
    }
    else {
	$hostName = `uname -n`; # on my Mac, this gives for example: dhcp-mac-016.sdsc.edu
	chomp($hostName);
	if ($thisOS eq "SunOS") {
	    $tmp=`nslookup $hostName`;
	    $i = index($tmp,"Name:");
	    $tmp = substr($tmp,$i);
	    $j = index($tmp, "Address:");
	    $hostFullNetName = substr($tmp,5,$j-5); # e.g. zuri.sdsc.edu
	    chomp($hostFullNetName);
	    chomp($hostFullNetName);
	    $i = rindex($hostFullNetName, " ");
	    $hostFullNetName = substr($hostFullNetName, $i+1);
	    $hostFullNetName =~ s/\t//;
	    $i = index($tmp, "Alias");
	    if ($i > 0) {
		$tmp=substr($tmp,0,$i);
	    }
	    $i = rindex($tmp," ");
	    $hostFullNetAddr = substr($tmp,$i+1);  # e.g. 132.249.32.192
	    chomp($hostFullNetAddr);
	    chomp($hostFullNetAddr);
	}
	else {
# run host to get full host.domain name, which
# returns for example: zuri.sdsc.edu has address 132.249.32.192
# grep for "has address" to avoid extra lines on some hosts (such as
# "mail is handled by")
	    $tmp=`host $hostName | grep "has address"`;  
	    $i = index($tmp, "has address");
	    if ($i > 0) {
		$i = index($tmp," ");
		$hostFullNetName = substr($tmp,0,$i); # zuri.sdsc.edu
		$i=rindex($tmp, " ");
		$testchar = substr($tmp, $i, 1);
		if ($testchar ne " ") {
# This seems to be an perl bug on some hosts.
# But the following workaround seems to work.
# My guess is that it is a bug in perl string-buffer management.
		    print "Perl rindex error detected; retrying\n";
		    print "testchar=:$testchar:\n";
		    $tmp3=$tmp;
		    $i5 = rindex($tmp3," ");
		    print "initial i=$i, retry i=$i5\n";
		    if ($i == $i5) {
			print "Retry failed, Perl rindex failed";
			die ("perl rindex problem");
		    }
		    print "rindex workaround succeeded (it appears), continuing\n";
		    $i=$i5;
		}
		$hostFullNetAddr = substr($tmp,$i+1);  # 132.249.32.192
		chomp($hostFullNetAddr);
	    }
	    else {
		$tmp=`host $hostName | grep "Aliases:"`;  
		$i = index($tmp, "Aliases:");
		if ($i < 0) {
		    print "Lookup of the local host, $hostName, failed\n";
		    die "Host DNS lookup failed";
		}
		$k = index($tmp,$hostName,$i);
	        $j = index($tmp,",",$k);
		$hostFullNetName = substr($tmp,$k,$j-$k); # zuri.sdsc.edu
		$i = index($tmp,",");
	        $j = rindex($tmp," ",$i);
		$hostFullNetAddr = substr($tmp,$j+1,$i-$j-1);  # 132.249.32.192
		chomp($hostFullNetAddr);
	    }
	}
    }
    print "This script is $Version\n";
    print "This host is $hostName\n";
    print "This host full network name is $hostFullNetName\n";
    print "This host full network address is $hostFullNetAddr\n";
    $homeDir=$ENV{'HOME'};
    print "Your home directory is $homeDir\n";
}

sub createLocalSettings() {

    if ($SubsetMode eq "3") {
# if reusing MCAT, skip all this stuff
	print "Skipping a few createLocalSettings steps for SubsetMode 3\n";
	$subState=4;
    }

    #  Extract the builtin password for "srb"  (so 
    #        nothing confidential is in this script).
    $keyLine=`grep "MDAS_AU_AUTH_KEY values (1" $startDir/$SRB_DIR/MCAT/data/catalog.install.psg`;
    $left=index($keyLine,"'");
    $right=rindex($keyLine,"'");
    $pw=substr($keyLine,$left+1,$right-$left-1);
#   print "The bootstrap srb user password is $pw \n";

    # set environment to use predefined admin acct (created as part of "E")
    $ENV{'srbUser'}="srb";
    $ENV{'srbAuth'}=$pw;
    $ENV{'mdasDomainName'}="sdsc";

    $bypassExitCheck=0;
    if ($thisOS eq "Darwin") {
	$bypassExitCheck=1;  # on Mac, we get weird exit codes somehow
    }

    print "chdir'ing to: $SRB_DIR/MCAT/bin\n";
    chdir "$SRB_DIR/MCAT/bin" || die "Can't chdir to $SRB_DIR/MCAT/bin";
    if ($subState eq "0") {
	runCmd(1,"./ingestToken Domain $YOUR_DOMAIN gen-lvl4");
#          (bypass the exit check on this because if the domain already
#           exists, this will fail.)
	$subState++;
	saveState();
    }
    if ($subState eq "1") {
	runCmd($bypassExitCheck,"./ingestUser $YOUR_ADMIN_NAME \'$YOUR_ADMIN_PW\' $YOUR_DOMAIN sysadmin '' '' ''");
	$subState++;
	saveState();
    }

    if ($subState eq "2") {
	runCmd($bypassExitCheck,"./ingestLocation '$hostName' '$hostFullNetName:NULL.NULL' 'level4' $YOUR_ADMIN_NAME $YOUR_DOMAIN");
	$subState++;
	saveState();
    }

    if ($subState eq "3") {
#       change the builtin srb@sdsc user to use your admin password instead
#       of the builtin one.
	runCmd($bypassExitCheck,"./modifyUser changePassword srb sdsc \'$YOUR_ADMIN_PW\'");
	$subState++;
	saveState();
    }


    # create the .srb directory and env files
    if ($subState eq "4") {
 	if (-e "$homeDir/.srb") {
 	    if (-e "$homeDir/.srb/.MdasEnv") {
		if ($SAFE_MODE eq "1") {
		    die("SAFE_MODE is 1 and you already have a ~/.srb/.MdasEnv file");
		}
		$dateStr=`date | sed 's/ /_/g'`;
		chomp($dateStr);
 		runCmdNoLog(0,"mv $homeDir/.srb/.MdasEnv $homeDir/.srb/.MdasEnv.old.$dateStr");
 	    }
	    if (-e "$homeDir/.srb/.srbAuthFile") {
		if ($SAFE_MODE eq "1") {
		    die("SAFE_MODE is 1 and you have a ~/.srb/.srbAuthFile");
		}
		runCmd(0, "rm -f $homeDir/.srb/.srbAuthFile");
	    }
	    $srbAuthFile=$ENV{'SRB_AUTH_FILE'};
	    if ($srbAuthFile and -e $srbAuthFile) {
		if ($SAFE_MODE eq "1") {
		    die("SAFE_MODE is 1 and you have an SRB_AUTH_FILE: $srbAuthFile");
		}
		runCmd(0, "rm -f $srbAuthFile");
	    }
 	}
 	else {
	    print "mkdir'ing: $homeDir/.srb\n";
 	    mkdir("$homeDir/.srb", 0700);
 	}
	print "Creating $homeDir/.srb/.MdasEnv file\n";
	writeFile("$homeDir/.srb/.MdasEnv", "mdasCollectionName \'/$YOUR_ZONE/home/$YOUR_ADMIN_NAME.$YOUR_DOMAIN\'\nmdasCollectionHome \'/$YOUR_ZONE/home/$YOUR_ADMIN_NAME.$YOUR_DOMAIN\'\nmdasDomainName \'$YOUR_DOMAIN\'\nmdasDomainHome \'$YOUR_DOMAIN\'\nsrbUser \'$YOUR_ADMIN_NAME\'\nsrbHost \'$hostFullNetName\'\n#srbPort \'5544\'\ndefaultResource \'$RESOURCE_NAME\'\n#AUTH_SCHEME \'PASSWD_AUTH\'\n#AUTH_SCHEME \'GSI_AUTH\'\nAUTH_SCHEME \'ENCRYPT1\'\n");

# comment out srbHost if so requested (for special tests)
	if ($UnsetHost) {
	    runCmdNoLog(0, 
		"cat $homeDir/.srb/.MdasEnv | sed s/srbHost/#srbHost/g > $homeDir/.srb/.MdasEnvTmp348594578");
	    unlink("$homeDir/.srb/.MdasEnv");
	    rename("$homeDir/.srb/.MdasEnvTmp348594578",
		   "$homeDir/.srb/.MdasEnv");
	}

	if (-e "$homeDir/.srb/.MdasAuth") {
	    if ($SAFE_MODE eq "1") {
		die("SAFE_MODE is 1 and you already have a ~/.srb/.MdasAuth file");
	    }
	    $dateStr=`date | sed 's/ /_/g'`;
	    chomp($dateStr);
	    runCmdNoLog(0,"mv $homeDir/.srb/.MdasAuth $homeDir/.srb/.MdasAuth.old.$dateStr");
	}
	print "Creating $homeDir/.srb/.MdasAuth file\n";
	writeFile("$homeDir/.srb/.MdasAuth", $YOUR_ADMIN_PW);

	$subState++;
	saveState();
    }
    if ($subState eq "5") {
#        Switch to the new user at this point.
        $ENV{'srbUser'}=$YOUR_ADMIN_NAME;
	$ENV{'srbAuth'}=$YOUR_ADMIN_PW;
	$ENV{'mdasDomainName'}=$YOUR_DOMAIN;

	print "chdir'ing to: $SRB_INSTALL_DIR/bin\n";
	chdir "$SRB_INSTALL_DIR/bin";
	runCmdNoLog(0,"./runsrb");
	print "sleeping a couple seconds\n";
	sleep 2;
	runCmdNoLog(0, "ps $psOptions | grep srb | grep -v grep");
	print "If the srb server is running OK, you should see srbMaster and srbServer here:\n";
	print $cmdStdout;
	print "chdir'ing to: $startDir/$SRB_DIR/MCAT/bin\n";
	chdir "$startDir/$SRB_DIR/MCAT/bin" || die "Can't chdir to $SRB_DIR/MCAT/bin";
	$subState++;
	saveState();
    }

# Do this last so the resource will be owned by the new admin account
# (especially important for Zones).
    if ($subState eq "6" and $SubsetMode ne "3") {
#        Be sure we have switched to the new user at this point.
        $ENV{'srbUser'}=$YOUR_ADMIN_NAME;
	$ENV{'srbAuth'}=$YOUR_ADMIN_PW;
	$ENV{'mdasDomainName'}=$YOUR_DOMAIN;
	runCmd($bypassExitCheck,"./ingestResource '$RESOURCE_NAME' 'unix file system' '$hostName' '$RESOURCE_DIR/?USER.?DOMAIN/?SPLITPATH/?PATH?DATANAME.?RANDOM.?TIMESEC' permanent 0");
#
# Create a second resource if requested
	if ($RESOURCE_NAME2) {
	    runCmd($bypassExitCheck,"./ingestResource '$RESOURCE_NAME2' 'unix file system' '$hostName' '$RESOURCE_DIR2/?USER.?DOMAIN/?SPLITPATH/?PATH?DATANAME.?RANDOM.?TIMESEC' permanent 0");
	}
	$subState++;
	saveState();

    }

    $state++;
    $subState=0;
    saveStateQuiet();
    chdir "$startDir" || die "Can't chdir to $startDir";
}


sub doZones() {
#  Set up Zones (new in SRB 3.0.0)

#   Switch from the ENV variables to the new user (via the .MdasEnv).
    $ENV{'srbUser'}='';
    $ENV{'srbAuth'}='';
    $ENV{'mdasDomainName'}='';

    print "chdir'ing to: $startDir/$SRB_DIR\n";
    chdir "$startDir/$SRB_DIR" || die "Can't chdir to $startDir/$SRB_DIR";

    runCmdNoLog(1, "./utilities/bin/Sexit");  # clear possible old Sinit env
    print "sleeping a second\n";
    sleep 1;
    runCmdNoLog(0, "./utilities/bin/Sinit");  # initialize for Szone

    if ($SubsetMode eq "3") {
# if reusing MCAT, skip all the rest
	runCmdNoLog(1, "./utilities/bin/Sexit");
	$state++;
	$subState=0;
	saveStateQuiet();
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }

# Change the local zone name
    if ($subState eq "0") {
	runCmdTwice(0, "./utilities/bin/Szone -C demozone $YOUR_ZONE");
#       There is a rare problem where this will fail, so as a workaround
#       the runCmdTwice routine will try it up to two times.
	$subState++;
	print "running Sls to clear out the waiting Server with the old zone\n";
	runCmdNoLog(1, "./utilities/bin/Sls foo"); # clear out waiting Server
	saveState();
    }

# Add the location to the zone, and also change the comment
# (this script uses hostName as the Location name)
    $now=`date`;
    chomp($now);
    if ($subState eq "1") {
	runCmd(0, "./utilities/bin/Szone -M $YOUR_ZONE $hostName '' '" . "$YOUR_ADMIN_NAME" . "@" . "$YOUR_DOMAIN" . "' '' 'Created $now'");
	$subState++;
	saveState();
    }


    if (!$REMOTE_ZONE) {
	print "REMOTE_ZONE not defined, skipping remote zone installation\n";
	runCmdNoLog(1, "./utilities/bin/Sexit");
	$state++;
	$subState=0;
	saveStateQuiet();
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }

    chdir "MCAT/bin" || die "Can't chdir to MCAT/bin";
# Create the remote Domain
    if ($subState eq "2") {
	runCmd(1,"./ingestToken Domain $REMOTE_DOMAIN gen-lvl4");
#          (bypass the exit check on this because if the domain already
#           exists, this will fail.)
	$subState++;
	saveState();
    }

# Create the remote zone user
    if ($subState eq "3") {
	runCmd($bypassExitCheck,"./ingestUser $REMOTE_ADMIN_NAME $REMOTE_ADMIN_PW $REMOTE_DOMAIN sysadmin '' '' ''");
	$subState++;
	saveState();
    }

# Create the remote Location
    if ($subState eq "4") {
	runCmd($bypassExitCheck,"./ingestLocation '$REMOTE_LOCATION' '$REMOTE_HOST_ADDR:NULL.NULL' 'level4' $REMOTE_ADMIN_NAME $REMOTE_DOMAIN");
	$subState++;
	saveState();
    }

# Create the remote Zone
    if ($subState eq "5") {
	runCmd(0, "../../utilities/bin/Szone -r $REMOTE_ZONE $REMOTE_LOCATION 0 $REMOTE_ADMIN_NAME" . "@" . "$REMOTE_DOMAIN '' ''");
	$subState++;
	saveState();
    }

# Change the remote admin user to the new Zone
    if ($subState eq "6") {
	runCmd(0, "../../utilities/bin/Szone -U $REMOTE_ZONE $REMOTE_ADMIN_NAME $REMOTE_DOMAIN");
	$subState++;
	saveState();
    }

    runCmdNoLog(1, "./utilities/bin/Sexit");
    $state++;
    $subState=0;
    saveStateQuiet();
    chdir "$startDir" || die "Can't chdir to $startDir";
}


sub installMcatDB() {

#   Run MCAT postgres table insert script
    if ($subState eq "0" and $SubsetMode lt "2") {
	print "chdir'ing to: $SRB_DIR/MCAT/data\n";
	chdir "$SRB_DIR/MCAT/data" || die "Can't chdir to $SRB_DIR/MCAT/data";
	unlink("myinstall.results.psg");
	if ($thisOS eq "SunOS" or $thisOS eq "AIX" or $thisOS eq "HP-UX") {
	    runCmdNoLog(0,"$postgresInstallDir/bin/psql $DB_NAME < catalog.install.psg > myinstall.results.psg 2>&1");
	}
	else {
	    runCmdNoLog(0,"$postgresInstallDir/bin/psql $DB_NAME < catalog.install.psg >& myinstall.results.psg");
	}
	print "It is probably OK, but you might compare myinstall.results.psg with install.results.psg to check differences\n";
	$subState++;
	saveState();
	print "chdir'ing to: $startDir\n";
	chdir "$startDir" || die "Can't chdir to $startDir";
    }

# Set up a odbcinst.ini file in the postgresInstallDir/etc directory.
# Normally postgres will use a ~/.odbc.ini file (and this script use to
# set that up) but it can also use this which is more convenient for our
# installation.

    if ($subState eq "1") {
# Need to move old .odbc.ini file if it exists since it would override
# the settings in the odbcinst.ini file.
	if (-e "$homeDir/.odbc.ini") {
	   if ($SAFE_MODE eq "1") {
               die("SAFE_MODE is 1 and you have a ~/.odbc.ini file");
           }
           $dateStr=`date | sed 's/ /_/g'`;
           chomp($dateStr);
           runCmdNoLog(1,"mv $homeDir/.odbc.ini $homeDir/.odbc.ini.old.$dateStr");
        }

	if ($SubsetMode lt "1") {
	    print "mkdir'ing: $postgresInstallDir/etc\n";
	    mkdir("$postgresInstallDir/etc", 0766);

	    runCmdNoLog(0,"echo '[PostgreSQL]\nDebug=0\nCommLog=0\nServername=$hostFullNetName\nDatabase=$DB_NAME\nUsername=$YOUR_POSTGRES_ADMIN_NAME\n' > $postgresInstallDir/etc/odbcinst.ini");
	    if ($POSTGRES_PORT) {
		runCmdNoLog(0,"echo 'Port=$POSTGRES_PORT\n' >> $postgresInstallDir/etc/odbcinst.ini");
	    }
	}
	else {
	    runCmdNoLog(0,"echo '[PostgreSQL]\nDebug=0\nCommLog=0\nServername=$hostFullNetName\nDatabase=$DB_NAME\nUsername=$YOUR_POSTGRES_ADMIN_NAME\n' > $homeDir/.odbc.ini");
	    if ($POSTGRES_PORT) {
		runCmdNoLog(0,"echo 'Port=$POSTGRES_PORT\n' >> $homeDir/.odbc.ini");
	    }
	}

	$subState++;
	saveState();
    }

    if ($subState >= 2 && $subState <= 4) {
#       Need to run commands from MCAT/bin so that they can find ../data 
#       (Or could set srbData environment variable.)
	print "chdir'ing to: $SRB_DIR/MCAT/bin\n"; 
	chdir "$SRB_DIR/MCAT/bin" || die "Can't chdir to $SRB_DIR/MCAT/bin";
    }

#   Test commuincation to postgres
    if ($subState eq "2") {
        print "running: ./test_srb_mdas_auth a b c\n";
	$testResult=`./test_srb_mdas_auth a b c`;
	if (index($testResult,"-3206") eq -1) {
	    $envLang=$ENV{'LANG'};
	    if (index($envLang,"UTF-8")>0) {
		printf("Your environment variable LANG is set to $envLang,\n");
		printf("which is known to be a problem, at least sometimes.\n");
		printf("You might unsetting that and retrying.\n");
	    }
	    die("failed to communicate to postgres");
	}
	$subState++;
	saveState();
    }

    if ($SubsetMode eq "2") {
	$state++;
	$subState=0;
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }

#   Do full MCAT test
    if ($subState eq "3") {
	$oldPath=$ENV{'PATH'};
	$ENV{'PATH'}="$startDir/$SRB_DIR/MCAT/bin:$oldPath";
	$bypassExitCheck=0;
	if ($thisOS eq "Darwin") {
	    $bypassExitCheck=1;  # on Mac, we get weird exit codes somehow
	}
	if ($thisOS eq "SunOS") {
	    $bypassExitCheck=1;  # also on Solaris.
	}
	runCmd($bypassExitCheck,"../data/test.catalog");
	$subState++;
	saveState();
    }

#   Try to check the results
    $referenceLog="../data/test.results.ora";  # the old ref log
    if (-e "../data/test.catalog.reference.log") { # New one is here
	$referenceLog="../data/test.catalog.reference.log"; # use it
    }
    if ($subState eq "4") {
	runCmd(1,"diff $startDir/installE4.log $referenceLog");
	$wc=`cat $startDir/installE5.log | wc -l`;
	chomp($wc);
	print "There are $wc lines of diffences.\n";
	if ($wc != 0) {
	    if ($wc < 40) {
		print "There are sometimes small differences like these\n";
		print "due to changes in postgresql versions.\n";
		print "This is probably OK, but you might examine these manually.\n";
	    }
	    else {
		die "Too many differences in test results; please check it.";
	    }
	}
    }
    $state++;
    $subState=0;
    chdir "$startDir" || die "Can't chdir to $startDir";
}

sub runPostgres() {

    if ($SubsetMode ge "2") {
	print "Skipping all runPostgres steps as this script is configured to use an existing one.\n";
	$state++;
	$subState=0;
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }
    if ($SubsetMode eq "1") {
	print "Skipping some runPostgres steps as this script is configured to use an existing one.\n";
	$subState=3;   # Skip down to create the db
    }

    if ($subState eq "0") {
        # Previously, this script would create the data subdir, but
        # that can cause problems in that the mode can't be set right
        # and initdb would fail trying to chmod it.  Seems to work OK
        # to just skip the mkdir.

	if ($thisOS eq "Darwin") {
# On Macs, lc-collate=C isn't needed and caused problems with not enough
# shared memory.
	    runCmd(0,"$postgresBin/initdb -D $postgresData");
	}
	else {
# Include --lc-collate=C to make sure postgres returns sorted items
# in the order needed.
	    runCmd(0,"$postgresBin/initdb --lc-collate=C -D $postgresData");
	}

	if ($thisOS eq "Darwin") {
        # Mac gets error in postges starting if LC_TIME isn't commented out
	    runCmdNoLog(0, "cat $postgresInstallDir/data/postgresql.conf | sed s/LC_TIME/#LC_TIME/g > $postgresInstallDir/data/postgresql.conf.tmp123");
	    unlink("$postgresInstallDir/data/postgresql.conf");
	    rename("$postgresInstallDir/data/postgresql.conf.tmp123",
		   "$postgresInstallDir/data/postgresql.conf");
	} 
	$subState++;
	saveState();
   }
    if ($subState eq "1") {
	if (index($POSTGRES_FILE,"7.2.3") gt 0) {
            # older version had different format
	    runCmdNoLog(0,"echo host all $hostFullNetAddr 255.255.255.255 trust | cat >> $postgresData/pg_hba.conf");
	}
	else {
            # this is right for 7.3.3, not sure about intermediate
	    runCmdNoLog(0,"echo host all all $hostFullNetAddr 255.255.255.255 trust | cat >> $postgresData/pg_hba.conf");
	}
	$subState++;
	saveState();
    }
    if ($subState eq "2") {
        runCmdNoLog(0, "$postgresBin/pg_ctl start -o '-i' -l $postgresData/pgsql.log");
	$subState++;
	saveState();
	print "sleeping a few seconds\n"; # 8.0.1 seems to need > 2
	sleep 6;
    }
    if ($subState eq "3") {
	runCmd(0,"$postgresBin/createdb $createDbOpts $DB_NAME");
	$subState++;
	saveState();
    }
    $state++;
    $subState=0;
    chdir "$startDir" || die "Can't chdir to $startDir";
}

sub buildPostgres() {
    test64Addr();  # before starting, make sure not 64-bit host

    if ($SubsetMode ge "1") {
	print "Skipping postgres build as this script is configured to use an existing one.\n";
	$state++;
	$subState=0;
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }

    if (rindex($POSTGRES_FILE,"gz") gt 0) {
	if ($subState eq "0") {
	    if (-e $postgresTarFile) {
		print "Skipping gzip -d as the uncompressed tar file already exists\n";
	    }
	    else {
		runCmd(0,"gzip -d $POSTGRES_FILE");
	    }
	}
    }
    else {
	print "Skipping gzip -d as the tar file is already uncompressed\n";
    }
    if ($subState eq "0") {
	$subState++;
	saveState();
    }

    if ($subState eq "1") {
	runCmd(0,"tar xf $postgresTarFile");
	$subState++;
	saveState();
    }

    print "chdir'ing to: $postgresDir\n";
    chdir "$postgresDir" || die "Can't chdir to $postgresDir";

    if ($subState eq "2") {
        $postgresConf="./configure --prefix=$postgresInstallDir --enable-odbc --without-readline";
	if ($thisOS eq "SunOS" or $thisOS eq "HP-UX") {
            $postgresConf = "$postgresConf" . " --without-zlib";
	}
	if ($POSTGRES_PORT) {
            $postgresConf = "$postgresConf" . " --with-pgport=$POSTGRES_PORT";
	}
        runCmd(0,"$postgresConf");
	$subState++;
	saveState();
    }

    if ($subState eq "3") {
	runCmd(0,"$gmake");
	$subState++;
	saveState();
    }

    if ($subState eq "4") {
	runCmd(0,"$gmake install");
	$subState++;
	saveState();
    }

    $state++;
    $subState=0;
    chdir "$startDir" || die "Can't chdir to $startDir";
}

sub buildOdbc() {
    if ($SubsetMode ge "1") {
	print "Skipping odbc build as this script is configured to use an existing one\n";
	$state++;
	$subState=0;
	chdir "$startDir" || die "Can't chdir to $startDir";
	return;
    }

    $odbcTarFile = $ODBC_FILE;
    if (rindex($ODBC_FILE,"gz") gt 0) {
	$odbcTarFile = substr($ODBC_FILE,0,-3);
	if ($subState eq "0") {
	    if (-e $odbcTarFile) {
		print "Skipping gzip -d as the uncompressed tar file already exists\n";
	    }
	    else {
		runCmd(0,"gzip -d $ODBC_FILE");
	    }
	}
    }
    if ($subState eq "0") {
	$subState++;
	saveState();
    }
    $odbcDir=substr($odbcTarFile,0,-4);

    $postgresInt="$postgresDir/src/interfaces";

    print "chdir'ing to: $postgresInt\n";
    chdir "$postgresInt" || die "Can't chdir to $postgresInt";

    print "mkdir'ing: odbc\n";
    mkdir("odbc", 0700);
    print "chdir'ing to: odbc\n";
    chdir "odbc" || die "Can't chdir to odbc";

    if ($subState eq "1") {
	runCmd(0,"tar xf $startDir/$odbcTarFile");
	runCmdNoLog(0,"mv $odbcDir/* .");
	$subState++;
	saveState();
    }

    if ($subState eq "2") {
	runCmd(0,"./configure --prefix=$postgresInstallDir --enable-static");
	if ($thisOS eq "SunOS") {
# Patch ODBC's Makefile to include the needed nsl and socket libraries
           if (`grep nsl Makefile` eq "") {
	       runCmdNoLog(0,"cat Makefile | sed 's/LIBS =/LIBS =-lnsl -lsocket/g' > Makefile2");
	       unlink("Makefile");
	       runCmdNoLog(0,"mv Makefile2 Makefile");
	   }
	} 
	$subState++;
	saveState();
    }

    if ($subState eq "3") {
	runCmd(0,"$gmake");
	$subState++;
	saveState();
    }

    if ($subState eq "4") {
	runCmd(0,"$gmake install");
	if (-e "$postgresInstallDir/lib/psqlodbc.a") { # if psqlodbc.a  exists
#           copy it to proper lib file (seems to be needed on some machines).
	    runCmd(0,"cp $postgresInstallDir/lib/psqlodbc.a $postgresInstallDir/lib/libpsqlodbc.a");
	}
	runCmd(0,"cp iodbc.h isql.h isqlext.h $postgresInstallDir/include");
	$subState++;
	saveState();
    }

    if ($thisOS eq "Darwin") {
	if ($subState eq "5") {
# Thru trial and error, I found that these commands will create a link
# library with no missing externals.  This cp is a hack, but I'm not
# sure the right way to create what we want (it avoids a missing
# external of _globals).  Also, this whole thing of creating a .a file
# from all the .o's via libtool is odd, but the odbc configure/make
# doesn't seem to handle it right.
	    runCmdNoLog(0,"cp psqlodbc.lo psqlodbc.o");   
	    runCmdNoLog(0,"libtool -o libpsqlodbc.a *.o");
	    runCmdNoLog(0,"cp libpsqlodbc.a $postgresInstallDir/lib");
	    chdir "$postgresInstallDir/lib" || die "Can't chdir to $postgresInstallDir/lib";
	    runCmdNoLog(0,"ranlib libpsqlodbc.a");
	    $subState++;
	    saveState();
	}
    }

    $state++;
    $subState=0;
    chdir "$startDir" || die "Can't chdir to $startDir";
}

sub buildSrb() {
    if ($subState eq "0") {
	if ($SRB_DIR and -e "$startDir/$SRB_DIR") {
	    print "Skipping decrypting of tar file and unpacking as $SRB_DIR already exists\n";
	    $subState++; # Also skip tar xf below
	}
	else {
	    if ($SRB_FILE_ALREADY_DECRYPTED eq "0") {
		print "**** After it pauses, enter the SRB distribution file password ****\n";
		if (index($SRB_FILE,"bf.tar") gt 0) {
		    runCmd(0,"openssl enc -d -bf-cbc -in $SRB_FILE -out $SRB_FILE.decrypted.tar");
		}
		else {
                    # first, create and run a small script to prompt 
                    # when pgp is waiting for input. (pgp will print some 
                    # stuff first, so without this it 
                    # is hard to see that pgp is waiting.)
                    writeFile("install_reminder.pl", "sleep 1;\nprint \"Enter the SRB distribution password: \";\n");
		    system('perl install_reminder.pl&');  # run in background
		    runCmd(0,"pgp -d $SRB_FILE -o $SRB_FILE.decrypted.tar");
		    unlink("install_reminder.pl");
		}
	    }
	}
	$subState++;
	saveState();
    }

    if ($subState eq "1") {
	if ($SRB_FILE_ALREADY_DECRYPTED eq "0") {
	    runCmd(0,"tar xf $SRB_FILE.decrypted.tar");
	    unlink "$SRB_FILE.decrypted.tar";
	}
	else {
	    runCmd(0,"tar xf $SRB_FILE");
	}
	$subState++;
	saveState();
    }

    setSRB_DIR();  # if not set and available, set $SRB_DIR
    
    print "chdir'ing to: $SRB_DIR\n";
    chdir "$SRB_DIR" || die "Can't chdir to $SRB_DIR";

    if ($subState eq "2") {
	$SRB_CONFIGURE_OPTIONS_PORT="";
	if ($SRB_PORT) {
	    $SRB_CONFIGURE_OPTIONS_PORT="--enable-srbport=" . "$SRB_PORT";
	}
	runCmd(0,"./configure $SRB_CONFIGURE_OPTIONS $SRB_CONFIGURE_OPTIONS_JAVA $SRB_CONFIGURE_OPTIONS_PORT");
	$subState++;
	saveState();
    }

    if ($subState eq "3") {
	runCmd(0,"$gmake");
	$subState++;
	saveState();
    }

    if ($subState eq "4") {
	print "chdir'ing to: MCAT\n";
	chdir "MCAT" || die "Can't chdir to MCAT";
	runCmd(0,"$gmake");
	$subState++;
	saveState();
	chdir ".." || die "Can't chdir to ..";
    }

    if ($subState eq "5") {
	if ($DO_JAVA) {
	    print "chdir'ing to: jargon\n";
	    chdir "jargon" || die "Can't chdir to jargon";
	    runCmd(0,"$gmake notgsi");
	    chdir ".." || die "Can't chdir to ..";
	}
	else {
	    print "Build of Jargon configured out, skipping (rebuild not needed anyway)\n";
	}
	$subState++;
	saveState();
    }

    if ($subState eq "6") {
	if ($DO_JAVA) {
	    print "chdir'ing to: MCAT/java\n";
	    chdir "MCAT/java" || die "Can't chdir to MCAT/java";
#           run gmake clean first to force rebuild and relink of admin objs
	    runCmd(0,"$gmake clean;$gmake");
	    chdir "../.." || die "Can't chdir to ../..";
	}
	else {
	    print "Build of Java Admin Tool configured out, skipping (rebuild not needed anyway)\n";
	}
	$subState++;
	saveState();
    }

    # create the MdasConfig file, set up for Postgres 
    if ($subState eq "7") {
	$userName = `whoami`;
	if (length($userName)<1) {
	    $userName = `who am i | cut -f1 -d " "`;
	    if (length($userName)<1) {
		$id=`id`;
		$l1=index($id,"(");
		$l2=index($id, ")");
		$userName=substr($id, $l1+1, $l2-$l1-1);
		if (length($userName)<1) {
		    die "Can't determine username of current login";
		}
	    }
	}
	runCmdNoLog(0,"mv $startDir/$SRB_DIR/data/MdasConfig $startDir/$SRB_DIR/data/MdasConfig.old");
	print "Creating $startDir/$SRB_DIR/data/MdasConfig file\n";
	writeFile("$startDir/$SRB_DIR/data/MdasConfig", "MDASDBTYPE       postgres\nMDASDBNAME       PostgreSQL\nMDASINSERTSFILE  $startDir/$SRB_DIR/data/mdas_inserts\nMETADATA_FKREL_FILE metadata.fkrel\nDB2USER           $userName\nDB2LOGFILE       $startDir/$SRB_DIR/data/db2logfile\nDBHOME        $postgresInstallDir/data\n");
	$subState++;
        saveState();
    }

    # change host name in mcatHost file
    if ($subState eq "8") {
        runCmdNoLog(0, "cat $startDir/$SRB_DIR/data/mcatHost | sed s/srb.sdsc.edu/$hostFullNetName/g > $startDir/$SRB_DIR/data/mcatHost2");
	`cp $startDir/$SRB_DIR/data/mcatHost2 $startDir/$SRB_DIR/data/mcatHost`;
	unlink "$startDir/$SRB_DIR/data/mcatHost2";
	$subState++;
	saveState();
    }

    # add localhost to hostConfig (seems to be needed on some hosts)
    if ($subState eq "9") {
	runCmdNoLog(0, "echo localhost $hostFullNetName >> $startDir/$SRB_DIR/data/hostConfig");
	$subState++;
	saveState();
    }

    if ($subState eq "10") {
	runCmd(0,"$gmake install");
	$subState++;
	saveState();
    }

    if ($thisOS eq "Darwin") {
        # Need different version of killsrb on Macs
	if ($subState eq "11") {
	    runCmdNoLog(0,"cp $startDir/$SRB_DIR/bin/killsrbMac $SRB_INSTALL_DIR/bin/killsrb");
	    $subState++;
	    saveState();
	}
    }

    $state++;
    $subState=0;
    chdir "$startDir" || die "Can't chdir to $startDir";
}

sub usage() {
    printf("usage: first edit a few defines in this file and then run it\n");
}

# run a command, and log its output to a file.
# if option is 0 (normal), check the exit code 
sub runCmd {
    my($option,$cmd) = @_;
    $workingState=$subState+1; # State/step we are currently working on
    $fullCmd = "$cmd > $startDir/install$state$workingState.log";
    print "running: $fullCmd \n";
    `$fullCmd`;
    $cmdStat=$?;
    if ($option == 0) {
	if ($cmdStat!=0) {
	    print "The following command failed:";
	    print "$fullCmd \n";
	    print "Exit code= $cmdStat \n";
	    die("command failed");
	}
    }
}

# run a command (without a log)
# if option is 0 (normal), check the exit code 
sub runCmdNoLog {
    my($option, $cmd) = @_;
    print "running: $cmd \n";
    $cmdStdout=`$cmd`;
    $cmdStat=$?;
    if ($option == 0) {
	if ($cmdStat!=0) {
	    print "The following command failed:";
	    print "$cmd \n";
	    print "Exit code= $cmdStat \n";
	    die("command failed");
	}
    }
}


# run a command once or twice, and log its output to a file.
# If the first attempt fails, sleep a second and try again; if it
# fails then, it fails.
sub runCmdTwice {
    my($option,$cmd) = @_;
    $workingState=$subState+1; # State/step we are currently working on
    $fullCmd = "$cmd > $startDir/install$state$workingState.log";
    print "running: $fullCmd \n";
    `$fullCmd`;
    $cmdStat=$?;
    if ($option == 0) {
	if ($cmdStat!=0) {
	    print "First try failed, sleeping a second to try again\n";
	    sleep 1;
	    $fullCmd = "$cmd >> $startDir/install$state$workingState.log";
	    `$fullCmd`;
	    $cmdStat=$?;
	    if ($cmdStat!=0) {
		print "The following command failed:";
		print "$fullCmd \n";
		print "Exit code= $cmdStat \n";
		die("command failed");
	    }
	}
    }
}


sub saveState {
    open(F, ">$fullStateFile");
    $_ = $state;
    print F;
    $_ = $subState;
    print F;
    close(F);
    print "Step $state $subState completed.\n";
}

sub saveStateQuiet {
    open(F, ">$fullStateFile");
    $_ = $state;
    print F;
    $_ = $subState;
    print F;
    close(F);
}

sub readState {
    if (open(F, "<$fullStateFile")) {
	read(F, $state, 1);
	read(F,$subState,2);
	close(F);
	chomp($subState); # remove possible trailing \n (vi forces one)
    }
    else {
	$state="A";
	$subState=0;
    }
    if ($state eq "G" or $state eq "H") {
	$srbDone=1;
    }
}

sub writeFile {
    my($file, $text) = @_;
    open(F, ">$file");
    $_ = $text;
    print F;
    close F;
}

sub getStackLimit {
    $SYS_getrlimit=194; # from /usr/include/sys/syscall.h
    $RLIMIT_STACK=3;    # from /usr/include/sys/resource.h
    $rlimit = pack(i2,0,0);
    $f=syscall($SYS_getrlimit,$RLIMIT_STACK,$rlimit);
    if ($f != 0) {
	print "Warning, syscall to getrlimit failed\n";
	return("0");
    }
    my($result1, $result2)=unpack(i2,$rlimit);
    return($result2);
}

sub setStackLimit {
    my($newValue)= @_;
    $SYS_setrlimit=195; # from /usr/include/sys/syscall.h
    $RLIMIT_STACK=3;    # from /usr/include/sys/resource.h
    $rlimit = pack(i2,0,$newValue);
    $f=syscall($SYS_setrlimit,$RLIMIT_STACK,$rlimit);
    if ($f != 0) {
	print "Warning, syscall to setrlimit failed\n";
    }
}

# Automatically determine and set the SRB_DIR variable if
# unset and it is available.
sub setSRB_DIR {
    if ($SRB_FILE) {  # SRB_FILE is set, so we will be unpacking it
	if ($state eq "A" or $state eq "B") {
	    return;  # too soon
	}
	if ($state eq "C") {
	    if ($subState eq "0" or $subState eq "1" ) {
		return;  # too soon
	    }
	}
    }
    if (!$SRB_DIR) {  # SRB_DIR not set
	$tmpVar=`ls -c1 -F -d SRB3* | grep /`;
        chomp($tmpVar);
        chop($tmpVar); # remove trailing /
	if ($tmpVar) {
	    $SRB_DIR = $tmpVar;
	    print "Note: SRB_DIR determined to be " . $SRB_DIR . "\n";
	}
    }
}

# Stop the SRB servers
sub stopSrbServers {
    if ($srbDone eq "1") {
    # have completed SRB installation, stop it too
	print "chdir'ing to: $SRB_INSTALL_DIR/bin\n";
	chdir "$SRB_INSTALL_DIR/bin";
	writeFile("tty_input_yes","y\n");
	print "You may see an error that a process is not killed,\n";
	print "this is normal as the killsrb script attempts to kill\n";
	print "each srb process twice.\n";
	runCmdNoLog(1, "./killsrb < tty_input_yes");
	print "chdir'ing to: ../..\n";
	chdir "../..";
    }
}

# Start SRB Server
sub startSrbServers {
    if ($srbDone eq "1") {
    # have completed SRB installation, start it too
	print "chdir'ing to: $SRB_INSTALL_DIR/bin\n";
	chdir "$SRB_INSTALL_DIR/bin";
	print "sleeping a second\n";
	sleep 1; # postgres sometimes needs a little time to setup
	runCmdNoLog(0, "./runsrb");
	chdir "../..";
    }
}

# Depending on the state, stop running Postgres and SRB servers
sub stopServers {
    $Servers = "";
    if ($srbDone eq "1") {
    # have completed SRB installation, stop it too
	print "chdir'ing to: $SRB_INSTALL_DIR/bin\n";
	chdir "$SRB_INSTALL_DIR/bin";
	writeFile("tty_input_yes","y\n");
	print "You may see an error that a process is not killed,\n";
	print "this is normal as the killsrb script attempts to kill\n";
	print "each srb process twice.\n";
	runCmdNoLog(1, "./killsrb < tty_input_yes");
	$Servers = "SRB";
	print "chdir'ing to: ../..\n";
	chdir "../..";
    }
    if ($SubsetMode lt "1") {
	runCmdNoLog(1, "$postgresBin/pg_ctl stop");
	if ($Servers) {
	    $Servers = $Servers . " and Postgres";
	}
	else {
	    $Servers = $Servers . "Postgres";
	}
    }
    print "Done stopping " . $Servers . " servers\n";
}

# Test if this host uses 64-bit addressing, and if so, print some
# helpful information and quit.
sub test64Addr {
  unlink("installsrb64test.c");
  `echo "extern void exit(int status); int main() { char *foo; if (sizeof(foo)==8) exit(1); exit(0); }" > installsrb64test.c`;
  `cc installsrb64test.c -o installsrb64test`;
  `./installsrb64test`;
  $stat=$?;
  if ($stat == 0) {
      # not a 64 bit machine
      unlink("installsrb64test.c");
      unlink("installsrb64test");
      return;
  }
  if ($stat == -1) {
      # the cc command failed, try gcc
      `gcc installsrb64test.c -o installsrb64test`;
      `./installsrb64test`;
      $stat=$?;
  }
  unlink("installsrb64test.c");
  unlink("installsrb64test");
  if ($stat == 0) {
      return;  # not a 64 bit machine
  }
  if ($stat==256) {
      # exit code of 1 (shifted a few bits); this is a 64 bit machine
      print "This is host uses 64 bit addressing and the\n";
      print "MCAT currently does not support that.\n";
      print "One alternative is to install a full MCAT SRB on another host\n";
      print "and install a non-MCAT server on this one to provide access to\n";
      print "the local resource(s) (non-MCAT servers can handle 64-bit\n";
      print "addressing). See installServer.pl.\n";
      die("64 bit");
  }
  return;
}


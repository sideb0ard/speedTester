#!/usr/bin/perl -w
use strict;
use Net::FTP;
use Net::SFTP;
use Net::SFTP::Attributes;
use File::Basename;
use Getopt::Long;

# Set DEBUG equal to 1 to print debugging information
#local ($DEBUG) = 1;
#$| = 1;

my $DESTDIR="IODA_TEST_UPLOAD";
my $DESTFILE="25MBFLAC.file";
my $DIREXISTS=0;
my $FILEEXISTS=0;
my $DIRATTRIBS = Net::SFTP::Attributes->new();

my $FILE = "/usr/local/Scriptz/25MBFLAC.file"; 
unless ( -e $FILE ) {
    die "No file found for $FILE - $!\n";
}

my $FILESIZE = (-s $FILE) / 1048576; # MB

unless ( -f $FILE ) {
    die "No $FILE found\n";
}

chomp(my $date=`date +"%m-%d-%y"`);

my ($dsp,$address,$user,$pw,$protocol,$homedir,$port);

GetOptions (   'dsp=s' => \$dsp,
                'address=s' => \$address,
                'username=s' => \$user,
                'pw=s' => \$pw,
                'protocol=s' => \$protocol,
                'homedir=s' => \$homedir,
                'port=s' => \$port);

unless (defined $dsp && defined $address && defined $user && defined $protocol) {
    HELP_MESSAGE();
}

unless ($protocol =~ /[s]?ftp/i) {
    die "Protocol has to be either 'FTP' or 'SFTP'\n";
}

#if (!defined $homedir) { $homedir = '~'; }

print "\n\n#######################################################################\n";
print "## STARTING SPEED TESTS -- time is " . `date`;
print "## Settings -- DSP: $dsp / ADDRESS $address / USER: $user / PROTO: $protocol\n";
if (defined $homedir) { print "## Optional homedir specified -- $homedir\n"; }
if (defined $port) { print "## Optional port specified -- $port\n\n"; }

if ($protocol =~ m/^ftp/i) {
    doFTP($dsp,$address,$user,$pw,$homedir);
} elsif ($protocol =~ m/^sftp/i) {
    doSFTP($dsp,$address,$user,$pw,$homedir,$port);
} else {
    print "WUFF!!\n";
}


###################################

sub doFTP {
    my $dsp = shift;
    my $host = shift;
    my $login = shift;
    my $pass = shift;
    my $homedir = shift;

    eval {
	    print "Logging in to $host as user $login\n";
	
	    my  $ftp = Net::FTP->new("$host", Debug => 0)
	      or die "Cannot connect to $host : $@";
	    $ftp->login("$login","$pass") || die "DIED while logging in - DEID! Wrong password?\n";
	
	    if (defined($homedir)) {
	        print "Cwding into home dir..\n";
	        $ftp->cwd($homedir);
	    }
	
	    $ftp->mkdir($DESTDIR);
	    $ftp->cwd($DESTDIR) || die "SOMETHING IS FUUUUCKED UP!!\n";
	
	    my $start = time;
	    print "\n" . `date` . "Now uploading $FILE..\n";
	    $ftp->put("$FILE");
	    my $time_taken = time - $start;
	
	    print "\n" . `date` . "--Operation took $time_taken seconds to upload 1 file of $FILESIZE MB\n";
	    my $bw = ($FILESIZE * 8) / $time_taken;
	    printf "\n\nDSP: $dsp -- Bandwidth = %.2fMb/s\n\n", $bw;
        print "#######################################################################\n";
    1;
    } or do {
        print "Connection died - $@\n";
    return;
    }
}

sub doSFTP {
    my $dsp = shift;
    my $host = shift;
    my $login = shift;
    my $pass = shift;
    my $homedir = shift;
    my $port = shift;

    if (!defined $homedir) { $homedir = '.'; }
    if (!defined $port) { $port = '22'; }

    eval {
        print "Logging in to $host as user $login\n";

	    if(!defined $pass) {
	        print "Using Publick Key\n";
	    }
        my $sargs = "$host, user=>$login, ssh_args=>[port=>$port, protocol => '2,1', cipher => 'blowfish-cbc', compression => 1]";
	    print "my sftp = new($sargs)\n";
        #my $sftp = Net::SFTP->new($host, user=>$login ,password=>$pass, ssh_args=>[port=>$port, protocol => '2',  cipher => 'blowfish-cbc', compression => 'Zlib']) || die "YA BASS -- $!!\n";
        my $sftp = Net::SFTP->new($host, user=>$login ,password=>$pass, ssh_args=>[port=>$port, protocol => '2',  cipher => 'blowfish-cbc']) || die "YA BASS -- $!!\n";
	    #my $sftp = Net::SFTP->new($sargs) || die "YA BASS -- $!!\n";
	    print "Logged in fine.\n";
	
        # CHECK IF DEST ALREADY EXISTS AND IF NOT, CREATE IT..
	    $sftp->ls("$homedir",\&lookfordestdir); 
	    $DESTDIR = $homedir . "/" . $DESTDIR;
	    if ($DIREXISTS == 0) {
	        my $dir_creation_result = $sftp->do_mkdir("$DESTDIR",$DIRATTRIBS);
	        if ($dir_creation_result == 1) {
	            die "OH YODA!!! SOMETHING IS HORRIBLY WRONG WITH THE FORCE...\n";
	        }
	    }

        #CHECK IF DESTFILE EXISTS, IF SO, DELETE IT (SFTP DOESNT SEEM TO LIKE OVERWRITING)
        $sftp->ls("$DESTDIR",\&lookfordestfile);
        if ($FILEEXISTS ==1) {
            print "\nremoving previously uploaded file.\n\n";
            $sftp->do_remove("$DESTDIR/$DESTFILE");
        }
	
	    my $start = time;
	    print "\n" . `date` . "-- Now uploading $FILE to $host:$DESTDIR/$DESTFILE..\n";
	    $sftp->put("$FILE","$DESTDIR/$DESTFILE");
	    print "\n" . `date`  . "-- Finished uploading $DESTFILE..\n\n";
	
	    my $time_taken = time - $start;
	    print "Operation took $time_taken seconds to upload 1 file of $FILESIZE MB\n";
	    my $bw = ($FILESIZE * 8) / $time_taken;
	    printf "DSP: $dsp -- Bandwidth = %.2fMb/s\n\n", $bw;
        print "#######################################################################\n\n";
    1;
    } or do {
        print "\n** --  Connection died: $@\n";
        return;
    }
}

sub lookfordestdir {
    if ( $_[0]->{filename} =~ /$DESTDIR/ ) {
        $DIREXISTS = 1;
    }
}
sub lookfordestfile {
    if ( $_[0]->{filename} =~ /$DESTFILE/ ) {
        $FILEEXISTS = 1;
    }
}

sub HELP_MESSAGE {
    print "\n\n**bzzzzt** DOES NOT COMPUTE **zzzbcx* * *\n";
    print "\nUsage: ./$0 --dsp DSPNAME --address UPLOADSERVER --username USERNAME --pw password --protocol SFTP --homedir ioda --port 22\n";
    print "(password only needed if no SSH keys are used; homedir and port are optional - only needed if they are different from defaults\n";
    exit;
}

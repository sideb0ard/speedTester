#!/usr/bin/perl -w
use strict;
use Net::FTP;
use Net::SFTP;
use Net::SFTP::Attributes;
use Text::CSV;
use FileHandle;

# Set DEBUG equal to 1 to print debugging information
#local ($DEBUG) = 1;
#$| = 1;

my $DESTDIR="IODA_TEST_UPLOAD";
my $DIREXISTS=0;
my $DIRATTRIBS = Net::SFTP::Attributes->new();

my $FILESTOUPLOAD = 2;
my $FILESIZE = 25; # MB

chomp(my $date=`date +"%m-%d-%y"`);
open(REPORT, ">DSP-DELIVERY-SPEED-REPORTFILE-" . $date . ".txt") || die "DEID! : $!\n";
REPORT->autoflush(1);

print REPORT "DSP DELIVERY SPEED TESTS - $date\n";
print REPORT "=========================================\n\n";

my @rows;
my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                 or die "Cannot use CSV: ".Text::CSV->error_diag ();

my $file = "dsps.csv";
#open my $fh, "<:encoding(utf8)", "$file" or die "BARF!! can't open $file -- $!";
open my $fh, "$file" or die "BARF!! can't open $file -- $!";

print "Starting Speed test -- time is " . `date` . "\n\n";

while ( my $row = $csv->getline( $fh ) ) {
    my ($dsp, $address, $user, $pw, $protocol, $notes);
    next if ($row->[0] =~ m/service_id/);
    if (defined $row->[1]) { $dsp = $row->[1]; }
    if (defined $row->[8]) { $address = $row->[8]; }
    if (defined $row->[9]) { $user = $row->[9]; }
    if (defined $row->[10]) { $pw = $row->[10]; }
    if (defined $row->[11]) { $protocol = $row->[11]; }
    if (defined $row->[12]) { $notes = $row->[12]; }

    next unless (defined $dsp && defined $address && defined $protocol && defined $user && defined $pw);
    print "DSP: $dsp -- PROTOCOL: $protocol -- ADDRESS: $address -- USER: $user -- PASSWORD: $pw\n";
    if ($protocol =~ m/^ftp/i) {
        doFTP($dsp,$address,$user,$pw);
    } elsif ($protocol =~ m/^sftp/i) {
        doSFTP($dsp,$address,$user,$pw);
    } else {
        print "WUFF!!\n";
    }
}

sub doFTP {
    my $dsp = shift;
    my $host = shift;
    my $login = shift;
    my $pass = shift;

    print "In FTP sub-routine..\n"; 

    eval {
    print "Logging in to $host as user $login\n";
    #exit;

    my  $ftp = Net::FTP->new("$host", Debug => 0)
      or die "Cannot connect to $host : $@";
    $ftp->login("$login","$pass") || die "DIED while logging in - DEID\n";

    #if (defined($home)) {
    #    print "Cwding into home dir..\n";
    #    $ftp->cwd($home);
    #}

    $ftp->mkdir($DESTDIR);
    $ftp->cwd($DESTDIR) || die "SOMETHING IS FUUUUCKED UP!!\n";
    print "\n" . `date`  . "Now uploading test FLACS..\n";
    my $start = time;
    for (my $id = 1; $id <= $FILESTOUPLOAD; $id ++) {
        my $filename = "25MBFLAC$id.file";
        print "\n" . `date` . "Now uploading $filename..\n";
        $ftp->put("$filename")
        
    }
    my @dirlist = $ftp->ls();
    foreach my $item(@dirlist) {
        print "$item\n";
    }
    my $time_taken = time - $start;
    print "\n" . `date` . "--Operation took $time_taken seconds to upload $FILESTOUPLOAD files of $FILESIZE MB\n";
    my $bw = (($FILESTOUPLOAD * $FILESIZE) * 8) / $time_taken;
    printf "DSP: $dsp -- Bandwidth = %.2fMb/s\n", $bw;
    printf REPORT "DSP: $dsp -- Bandwidth = %.2fMb/s\n", $bw;
    1;
    } or do {
        print "Connection died.. trying next..\n";
    return;
    }
}

sub doSFTP {
    my $dsp = shift;
    my $host = shift;
    my $login = shift;
    my $pass = shift;
    print "\n" . `date`  . "-- IN SFTP SUB -- I gots $host -- $login -- $pass\n";

    eval {
    print "Logging in to $host as user $login\n";

    if($pass =~ m/passwordless/) {
        print "Using Publick Key\n";
    }
    my $sftp = Net::SFTP->new($host, user=>$login ,password=>$pass) || die "YA BASS!\n";
    #my $sftp = Net::SFTP->new($host, user=>$login ,password=>$pass,debug=>'false') || die "YA BASS!\n";
    $sftp->ls('.',\&detailz); 
    
    #print "DIREXISTS = $DIREXISTS\n";
    if ($DIREXISTS == 0) {
        my $dir_creation_result = $sftp->do_mkdir("$DESTDIR",$DIRATTRIBS);
        if ($dir_creation_result == 1) {
            die "OH YODA!!! SOMETHING IS HORRIBLY WRONG WITH THE FORCE...\n";
        }
    }
    print "Now uploading test FLACS..\n";
    my $start = time;
    for (my $id = 1; $id <= $FILESTOUPLOAD; $id ++) {
        my $filename = "25MBFLAC$id.file";
        print "\n" . `date` . "-- Now uploading $filename..\n";
        $sftp->put("$filename","$DESTDIR/$filename");
        print "\n" . `date`  . "-- Finished uploading $filename..\n\n";
    }
    my $time_taken = time - $start;
    print "Operation took $time_taken seconds to upload $FILESTOUPLOAD files of $FILESIZE MB\n";
    my $bw = (($FILESTOUPLOAD * $FILESIZE) * 8) / $time_taken;
    #printf "Bandwidth = %.2fMb/s\n", $bw;
    printf "DSP: $dsp -- Bandwidth = %.2fMb/s\n", $bw;
    printf REPORT "DSP: $dsp -- Bandwidth = %.2fMb/s\n", $bw;
    1;
    } or do {
        print "Connection died.. trying next..\n";
    return;
    }
}

sub detailz {
    my $file = $_[0]->{filename};
    if ( $_[0]->{filename} =~ /$DESTDIR/ ) {
        #print "WOOP! found tha dir!\n";
        $DIREXISTS=1;
    } else {
#        print "Nope, not that one..\n";
    }
}

#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use Carp;
use DBI;
use Getopt::Long;

my $verbose  = 0;
my @datafile = ();
my $index    = 0;
my $tmpdir   = "/tmp";
my $dbname   = "mgrast_ach_prod";
my $dbhost   = "kursk-3.mcs.anl.gov";
my $dbuser   = "mgrastprod";
my $usage    = qq(
DESCRIPTION: ($0)
load the ACH database tables with the inputted file data. Must be postgresql db.

USAGE:
  --datafile  source_data   Required. This may be multiple files by calling the option multiple times.
  --tmp_dir   dir           Optional. Dir to create temperary files. Default is '$tmpdir'
  --dbhost    db user       Optional. Server of database. Default is '$dbhost'
  --dbname    db name       Optional. Name of database. Default is '$dbname'
  --dbuser    db user       Optional. Owner of database. Default is '$dbuser'
  --index                   Optional. Create and load indexes when done. Default is off.
  --verbose                 Optional. Verbose output. Default is off.

);
if ( (@ARGV > 0) && ($ARGV[0] =~ /-h/) ) { print STDERR $usage; exit; }
if ( ! &GetOptions ('verbose!'    => \$verbose,
		    'index!'      => \$index,
		    'datafile=s'  => \@datafile,
		    'tmp_dir:s'   => \$tmpdir,
		    'dbhost:s'    => \$dbhost,
		    'dbname:s'    => \$dbname,
		    'dbuser:s'    => \$dbuser
		   ) )
  { print STDERR $usage; exit; }

if (@datafile == 0) { print STDERR $usage; exit; }

my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=$dbhost", $dbuser, '', {AutoCommit => 0});
unless ($dbh) { print STDERR "Error: " , DBI->error , "\n"; }

my $psql  = "psql -U $dbuser -h $dbhost -d $dbname";
my $count = 0;
my $tbls  = { tbl => { md5   => "md5_ontology",
		       func  => "functions",
		       src   => "sources"
		     },
	      idx => { md5   => ["id","md5","function","source"],
		       func  => ["name"],
		       src   => ["name"]
		     } };

&drop_table_indexes($dbh, $tbls->{tbl}{func}, $verbose);
&drop_table_indexes($dbh, $tbls->{tbl}{src}, $verbose);

my $func_ids = &get_id_set($dbh, $psql, $tbls->{tbl}{func}, '3', 'name', \@datafile, $verbose);
my $src_ids  = &get_id_set($dbh, $psql, $tbls->{tbl}{src}, '4', 'name', \@datafile, $verbose);
my ($funcID, $srcID);

my $data_tmp = "$tmpdir/data." . unpack("H*", pack("Nn", time, $$));
open(DTMP, ">$data_tmp") || die "Can not open $data_tmp: $!";

foreach my $dfile (@datafile) {
  open(DFILE, "$dfile") or die "Can't open file $dfile\n";
  if ($verbose) { print STDERR "Parsing $dfile ... \n"; }
  $count = 0;
  
  while (my $line = <DFILE>) {
    chomp $line;
    my ($md5, $id, $func, $source) = split(/\t/, $line);
    unless ($md5 && $id && $source) { next; }

    $funcID = ($func && exists($func_ids->{$func})) ? $func_ids->{$func} : '';
    $srcID  = $src_ids->{$source};

    if ($md5 && $id && $funcID && $srcID) {
      print DTMP join("\t", ($md5, $id, $funcID, $srcID)) . "\n";
    }
    
    $count += 1;
    unless ($count % 500000) {
      if ($verbose) { print STDERR "$count\t $md5 , $id , $func ($funcID) , $source ($srcID)\n"; }
    }
  }
  close DFILE;
}
close DTMP;

&drop_table_indexes($dbh, $tbls->{tbl}{md5}, $verbose);
&psql_copy($psql, $tbls->{tbl}{md5}, 'md5,id,function,source', $data_tmp, $verbose);
$dbh->commit;

if ($index) {
  foreach (('func','src','md5')) {
    &create_table_indexes($dbh, $tbls->{tbl}{$_}, $tbls->{idx}{$_}, $verbose);
  }
}

$dbh->commit;
$dbh->disconnect;
if ($verbose) { print STDERR "Done.\n"; }
exit 0;


sub drop_table_indexes {
  my ($dbh, $table, $v) = @_;

  my @rv;
  if ($v) { print STDERR "Disabling indexes for $table ...\n"; }
  my $sql = qq(SELECT ci.relname FROM pg_index i, pg_class ci, pg_class ct
               WHERE i.indexrelid=ci.oid AND i.indrelid=ct.oid AND i.indisprimary is false AND ct.relname='$table');
  my $idx = $dbh->selectcol_arrayref($sql);
  if ($idx && (@$idx > 0)) {
    foreach my $i (@$idx) { push @rv, $dbh->do("DROP INDEX IF EXISTS $i"); }
  }
  $dbh->commit;
  if ($v) { print STDERR join("\n", @rv) . "\n"; }
}

sub create_table_indexes {
  my ($dbh, $table, $indexes, $v) = @_;

  my @rv;
  foreach my $i (@$indexes) {
    my $x = $i;
    $x =~ s/,/_/g;
    my $sql = "CREATE INDEX ${table}_$x ON $table ($i)";
    if ($v) { print STDERR "$sql\n"; }
    push @rv, $dbh->do($sql);
  }
  $dbh->commit;
  if ($v) { print STDERR join("\n", @rv) . "\n"; }
}

sub psql_copy {
  my ($cmd, $table, $cols, $file, $v) = @_;

  my $psql = qq($cmd -c "COPY $table ($cols) FROM STDIN WITH NULL AS '';" < $file);
  unless (-s $file) {
    print STDERR "No data in '$file' to COPY to '$table', skipping\n"; return;
  }
  my $run  = &run_cmd($psql, $v);
  if ($run) { unlink($file); }
}

sub get_id_set {
  my ($dbh, $psql, $table, $cnum, $cname, $files, $v, $org_map) = @_;

  my $set = &get_name_id_from_db($dbh, $table, $v);
  my $tmp = "$tmpdir/$table." . unpack("H*", pack("Nn", time, $$));
  my $cmd = "cat " . join(" ", @$files) . " | cut -f$cnum | sort -u | sed '/^\\s*\$/d' | tr -c '[:print:][:cntrl:]' '[?*]'";

  # if already has values in table, just get unique new ones
  if ( scalar(keys %$set) > 0 ) {
    print STDERR "Running $cmd ...\nOutputing unique $table to $tmp ... " if ($v);
    open(TMP, ">$tmp") || die "Can not open $tmp: $!";
    foreach my $n (`$cmd`) {
      chomp $n;
      if (! exists $set->{$n}) { print TMP &clean_text($n) . "\n"; }
    }
    close TMP;
    print STDERR "Done\n" if ($v);
  }
  # else get unique all
  else {
    &run_cmd("$cmd > $tmp", $v);
  }
  &psql_copy($psql, $table, $cname, $tmp, $v);
  return &get_name_id_from_db($dbh, $table, $v);
}

sub get_name_id_from_db {
  my ($dbh, $table, $v) = @_;

  print STDERR "Getting data for $table ... " if ($v);
  my %set = ();
  my $all = $dbh->selectall_arrayref("SELECT name, _id FROM $table");
  if ($all && (@$all > 0)) {
    %set = map { $_->[0], $_->[1] } @$all;
  }
  print STDERR "Done - " . scalar(keys %set) . " $table\n" if ($v);

  return \%set;
}

sub clean_text {
  my ($text) = @_;

  if (! $text) { return $text; }
  my $clean = $text;
  $clean =~ s/^\s+//;
  $clean =~ s/\s+$//;
  $clean =~ s/\\/\\\\/g; # escape the escapes
  $clean =~ s/'/\\'/g;   # escape the single quotes
  return $clean;
}

sub run_cmd {
  my ($cmd, $v) = @_;

  if ($v) { print STDERR "Running: $cmd ...\n"; }
  my $r = system($cmd);
  if ($r == 0) {
    return 1;
  } else {
    die "ERROR: $cmd: $!\n"
  }
}

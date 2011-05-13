#!/usr/bin/env perl
# -*-mode:cperl; indent-tabs-mode: nil-*-

## Test adding, dropping, and changing herds via bucardo_ctl
## Tests the main subs: add_herd, list_herds, update_herd, remove_herd

use 5.008003;
use strict;
use warnings;
use Data::Dumper;
use lib 't','.';
use DBD::Pg;
use Test::More tests => 47;

use vars qw/$t $res $command $dbhX $dbhA $dbhB/;

use BucardoTesting;
my $bct = BucardoTesting->new({notime=>1})
    or BAIL_OUT "Creation of BucardoTesting object failed\n";
$location = '';

## Make sure A and B are started up
$dbhA = $bct->repopulate_cluster('A');
$dbhB = $bct->repopulate_cluster('B');

## Create a bucardo database, and install Bucardo into it
$dbhX = $bct->setup_bucardo('A');

## Grab connection information for each database
my ($dbuserA,$dbportA,$dbhostA) = $bct->add_db_args('A');
my ($dbuserB,$dbportB,$dbhostB) = $bct->add_db_args('B');

## Tests of basic 'add herd' usage

$t = 'Add herd with no argument gives expected help message';
$res = $bct->ctl('bucardo_ctl add herd');
like ($res, qr/Usage: add herd/, $t);

$t = q{Add herd works for a new herd};
$res = $bct->ctl('bucardo_ctl add herd foobar');
like ($res, qr/Created herd "foobar"/, $t);

$t = q{Add herd gives expected message if herd already exists};
$res = $bct->ctl('bucardo_ctl add herd foobar');
like ($res, qr/Herd "foobar" already exists/, $t);

$t = q{Add herd works when adding a single table that does not exist};
$res = $bct->ctl('bucardo_ctl add herd foobar nosuchtable');
like ($res, qr/No databases have been added yet/, $t);

$t = q{Add herd works when adding a single table};
$bct->ctl("bucardo_ctl add database bucardo_test user=$dbuserA port=$dbportA host=$dbhostA addalltables");
$res = $bct->ctl('bucardo_ctl add herd foobar bucardo_test1');
like ($res, qr/Herd "foobar" already exists .*Added table "public.bucardo_test1" to the herd plus/, $t);

$t = q{Add herd works when adding multiple tables};

$t = q{Add herd works when adding a single sequence};

$t = q{Add herd works when adding multiple sequences};

$t = q{Add herd works when adding same name table and sequence};

$t = q{Add herd works when adding tables via schema wildcards};

$t = q{Add herd works when adding tables via table wildcards};

exit;
## end add herd?

$t = q{Add database fails for non-existent database};
$res = $bct->ctl("bucardo_ctl add database foobarz user=$dbuserA port=$dbportA host=$dbhostA");
like ($res, qr/Connection test failed.*database "foobarz" does not exist/, $t);

$t = q{Add database fails for non-existent user};
$res = $bct->ctl("bucardo_ctl add database bucardo_test user=nobob port=$dbportA host=$dbhostA");
like ($res, qr/Connection test failed.* "nobob" does not exist/, $t);

$t = q{Add database fails for non-existent host};
$res = $bct->ctl("bucardo_ctl add database bucardo_test user=$dbuserA port=$dbportA host=badbucardohost");
like ($res, qr/Connection test failed.*could not translate host name/, $t);

$t = q{Add database works for non-existent cluster with --force flag};
$res = $bct->ctl('bucardo_ctl add database foobarz --force');
like ($res, qr/add anyway.*Added database "foobarz"/s, $t);

$t = 'Add database works for cluster A';
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=A user=$dbuserA port=$dbportA host=$dbhostA");
is ($res, qq{Added database "A"\n}, $t);

$t = q{Add database fails if using the same internal name};
$res = $bct->ctl("bucardo_ctl add db postgres name=A user=$dbuserA port=$dbportA host=$dbhostA");
like ($res, qr/Cannot add database: the name "A" already exists/, $t);

$t = q{Add database fails if same paramters given};
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=A2 user=$dbuserA port=$dbportA host=$dbhostA");
like ($res, qr/same parameters/, $t);

$t = 'Add database works for cluster B works with ssp=false';
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB ssp=0");
like ($res, qr/Added database "B"/, $t);

$t = 'List databases gives expected results';
$res = $bct->ctl('bucardo_ctl list databases');
my $statA = qq{Database: A\\s+Status: active\\s+Conn: psql -p $dbportA -U $dbuserA -d bucardo_test -h $dbhostA};
my $statB = qq{Database: B\\s+Status: active\\s+Conn: psql -p $dbportB -U $dbuserB -d bucardo_test -h $dbhostB \\(SSP is off\\)};
my $statz = qq{Database: foobarz\\s+Status: active\\s+Conn: psql .*-d foobarz};
my $regex = qr{$statA\n$statB\n$statz$}s;
like ($res, $regex, $t);

## Clear them out for some more testing
$t = q{Remove database works};
$res = $bct->ctl('bucardo_ctl remove db A B');
is ($res, qq{Removed database "A"\nRemoved database "B"\n}, $t);

## Tests of add database with group modifier

$t = 'Add database works when adding to a new dbgroup';
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=A user=$dbuserA port=$dbportA host=$dbhostA group=group1");
like ($res, qr/Added database "A".*Created database group "group1".*Added database "A" to group "group1" as target/s, $t);

$t = 'Add database works when adding to an existing dbgroup';
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB group=group1");
like ($res, qr/Added database "B" to group "group1" as target/s, $t);

$t = 'Add database works when adding to an existing dbgroup as role source';
$bct->ctl('bucardo_ctl remove db B');
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB group=group1:source");
like ($res, qr/Added database "B" to group "group1" as source/s, $t);

$t = q{Adding a database into a new group works with 'dbgroup'};
$bct->ctl('bucardo_ctl remove db B');
$res = $bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB dbgroup=group1:replica");
like ($res, qr/Added database "B" to group "group1" as target/s, $t);

## Tests for 'remove database'

$t = q{Remove database gives expected message when database does not exist};
$res = $bct->ctl('bucardo_ctl remove db foobar');
like ($res, qr/No such database: foobar/, $t);

$t = q{Remove database works};
$res = $bct->ctl('bucardo_ctl remove db B');
like ($res, qr/Removed database "B"/, $t);

$t = q{Able to remove more than one database at a time};
$bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB");
$res = $bct->ctl('bucardo_ctl remove db A B foobarz');
like ($res, qr/Removed database "A"\nRemoved database "B"/ms, $t);

## Tests for 'list databases'

$t = q{List database returns correct message when no databases};
$res = $bct->ctl('bucardo_ctl list db');
like ($res, qr/No databases/, $t);

$bct->ctl("bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB ssp=1");
$t = q{List databases shows the server_side_prepare setting};
$res = $bct->ctl('bucardo_ctl list database B -vv');
like ($res, qr/server_side_prepares = 1/s, $t);

$t = q{List databases accepts 'db' alias};
$res = $bct->ctl('bucardo_ctl list db');
like ($res, qr/Database: B/, $t);

## Tests for the "addall" modifiers

$t = q{Add database works with 'addalltables'};
$command =
"bucardo_ctl add db bucardo_test name=A user=$dbuserA port=$dbportA host=$dbhostA addalltables";
$res = $bct->ctl($command);
like ($res, qr/Added database "A"\nNew tables added: \d/s, $t);

$t = q{Remove database fails when it has referenced tables};
$res = $bct->ctl('bucardo_ctl remove db A');
like ($res, qr/remove all tables that reference/, $t);

$t = q{Remove database works when it has referenced tables and using --force};
$res = $bct->ctl('bucardo_ctl remove db A --force');
like ($res, qr/that reference database "A".*Removed database "A"/s, $t);

$t = q{Add database with 'addallsequences' works};
$res = $bct->ctl("bucardo_ctl remove dbgroup abc");
$command =
"bucardo_ctl add db bucardo_test name=A user=$dbuserA port=$dbportA host=$dbhostA addallsequences";
$res = $bct->ctl($command);
like ($res, qr/Added database "A"\nNew sequences added: \d/s, $t);

$t = q{Remove database respects the --quiet flag};
$res = $bct->ctl('bucardo_ctl remove db B --quiet');
is ($res, '', $t);

$t = q{Add database respects the --quiet flag};
$command =
"bucardo_ctl add db bucardo_test name=B user=$dbuserB port=$dbportB host=$dbhostB --quiet";
$res = $bct->ctl($command);
is ($res, '', $t);

$t = q{Update database gives proper error with no db};
$res = $bct->ctl('bucardo_ctl update db');
like ($res, qr/Usage:/, $t);

$t = q{Update database gives proper error with no items};
$res = $bct->ctl('bucardo_ctl update db foobar');
like ($res, qr/Usage:/, $t);

$t = q{Update database gives proper error with invalid database};
$res = $bct->ctl('bucardo_ctl update db foobar a=b');
like ($res, qr/Could not find a database named "foobar"/, $t);

$t = q{Update database gives proper error with invalid format};
$res = $bct->ctl('bucardo_ctl update db A blah blah');
like ($res, qr/Usage: update database/, $t);

$res = $bct->ctl('bucardo_ctl update db A blah123#=123');
like ($res, qr/Usage: update database/, $t);

$t = q{Update database gives proper error with invalid items};
$res = $bct->ctl('bucardo_ctl update db A foobar=123');
like ($res, qr/Cannot change "foobar"/, $t);

$t = q{Update database gives proper error with forbidden items};
$res = $bct->ctl('bucardo_ctl update db A cdate=123');
like ($res, qr/Sorry, the value of cdate cannot be changed/, $t);

$t = q{Update database works with a simple set};
$res = $bct->ctl('bucardo_ctl update db A port=1234');
like ($res, qr/Changed bucardo.db dbport from \d+ to 1234/, $t);

$t = q{Update database works when no change made};
$res = $bct->ctl('bucardo_ctl update db A port=1234');
like ($res, qr/No change needed for dbport/, $t);

$t = q{Update database works with multiple items};
$res = $bct->ctl('bucardo_ctl update db A port=12345 user=bob');
like ($res, qr/Changed bucardo.db dbport from \d+ to 1234/, $t);

$t = 'Update database works when adding to a new group';
$res = $bct->ctl('bucardo_ctl update db A group=group5');
like ($res, qr/Created database group "group5".*Added database "A" to group "group5" as target/s, $t);

$t = 'Update database works when adding to an existing group';
$res = $bct->ctl('bucardo_ctl update db B group=group5');
like ($res, qr/Added database "B" to group "group5" as target/, $t);

$t = 'Update database works when changing roles';
$res = $bct->ctl('bucardo_ctl update db A group=group5:master');
like ($res, qr/Changed role for database "A" in group "group5" from target to source/, $t);

$t = 'Update database works when removing from a group';
$res = $bct->ctl('bucardo_ctl update db B group=group2:replica');
## new group, correct role, remove from group1!
like ($res, qr/Created database group "group2".*Added database "B" to group "group2" as target.*Removed database "B" from group "group5"/s, $t);

$res = $bct->ctl('bucardo_ctl update db A status=inactive DBport=12345');
like ($res, qr/No change needed for dbport.*Changed bucardo.db status from active to inactive/s, $t);

$t = q{List database returns correct information};
$res = $bct->ctl('bucardo_ctl list dbs');
like ($res, qr/Database: A.*Status: inactive.*Database: B.*Status: active/s, $t);

$t = q{Remove database works};
$res = $bct->ctl('bucardo_ctl remove db A B --force');
like ($res, qr/that reference database "A".*Removed database "A".*Removed database "B"/s, $t);

$t = q{List database returns correct information};
$res = $bct->ctl('bucardo_ctl list dbs');
like ($res, qr/No databases/, $t);

exit;

END {
    $bct->stop_bucardo($dbhX);
    $dbhX and $dbhX->disconnect();
    $dbhA and $dbhA->disconnect();
    $dbhB and $dbhB->disconnect();
}

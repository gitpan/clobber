use Test::More tests => 15; #21
use File::Temp;
use Fcntl;
use vars '$NASTY';

no clobber;
my($fh, $openname) = File::Temp::tempfile();
close(STDIN);


#Test 1-arg
$NASTY = ">$openname";
eval{ open(NASTY); print NASTY "hi" };
ok($@ =~ /File exists/, "1-arg write: $@");


#Test proper 2-arg parsing for things that should be okay
#...also verifies stricture expression of 3-arg.
#|-

#readline() instead of waka-waka to prevent bogus:
#   Name "main::IN" used only once: possible typo
my $ret = eval{ open( IN, qq($^X -le "print 4" | ) ); readline(IN) } || '';
ok($ret eq "4\n", "Pipe-in: $@");

#XXX Proper testing would require user input,
#or a fork and reading the child's output
#OR pre/post -s of unbuffered output file
eval{ open(STDERR2, ">&STDERR") };
ok(!$@, "dup: $@");

eval{ open(STDOUT2, ">&=STDOUT") };
ok(!$@, "fdopen: $@");

#- #XXX
#>-
#>>
#+>>


#Default open
eval{ open(REOPEN, ">$openname") };
ok($@ =~ /File exists/, "2-arg write: $@");

eval{ open(REOPEN, '>', $openname) };
ok($@ =~ /File exists/, "3-arg write: $@");

eval{ open(REOPEN, "+>$openname") };
ok($@ =~ /File exists/, "2-arg write-read: $@");

eval{ open(REOPEN, '+>', $openname) };
ok($@ =~ /File exists/, "3-arg write-read: $@");

eval{ open(REOPEN, "+<$openname") };
ok($@ =~ /File exists/, "2-arg read-write: $@");

eval{ open(REOPEN, '+<', $openname) };
ok($@ =~ /File exists/, "3-arg read-write: $@");


#Default sysopen
my $sysoname = File::Temp::tmpnam();
sysopen(FIRST, $sysoname, O_CREAT|O_EXCL|O_WRONLY);
print FIRST scalar localtime;
close(FIRST);


eval{ sysopen(REOPEN, $sysoname, O_CREAT|O_EXCL|O_WRONLY) };
ok($@ =~ /File exists/, "O_WRONLY: $@");

eval{ sysopen(REOPEN, $sysoname, O_CREAT|O_EXCL|O_RDWR) };
ok($@ =~ /File exists/, "O_RDWR: $@");

eval{ sysopen(REOPEN, $sysoname, O_RDONLY|O_TRUNC) };
ok($@ =~ /File exists/, "O_TRUNC: $@");


#Rename
eval{ rename($openname, $sysoname) };
ok($@ =~ /File exists/, "rename: $@");


#Lax
{
  use clobber ':lax';
  #no fail +<, O_WRONLY, O_RDWR
}


#Test pragma reset
eval{ sysopen(REOPEN, $sysoname, O_CREAT|O_EXCL|O_WRONLY) };
ok($@ =~ /File exists/, "O_WRONLY x2, pragma scope reset: $@");


#-i

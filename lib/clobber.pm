package clobber;
use Carp;
use Fcntl;
use strict; no strict 'refs';
use vars '$VERSION'; $VERSION = 0.10_1;
eval "require Term::ReadKey";

BEGIN{ $^I||="~" }

sub unimport { #no strict 'refs';
  my $opt = $_[1] || '';
  $^H{'clobber-lax'} = $opt eq ':lax' ? 1 : 0;

  unless( exists($^H{clobber}) ){
      *{"CORE::GLOBAL::\L$_"} = \&{$_} foreach qw/OPEN RENAME SYSOPEN/;
  }
  $^H{'clobber'} = $ENV{'clobber.pm'} || 0;
}

sub import {
  my $opt = $_[1] || '';
  if( $opt eq ':lax' ){
    $^H{'clobber-lax'} = 1;
    &unimport();
  }
  else{
    $^H{'clobber'} = 1;
  }
}


sub OPEN(*;$@){
  my($handle, $mode, $file) = @_;
  my($testmode, $pipein) = $mode;
  my $scope = (caller 0)[10];

  my $stricture = $scope->{'clobber-lax'} ?
    qr/^\+>(?!>)|^>(?!&|>)/ : qr/^\+[<>](?!>)|^>(?!&|>)/;

  if( scalar(@_) == 1 ){ #no strict 'refs';
    unshift(@_, $mode = ${caller(1).'::'.$handle});
  }

  if( scalar(@_) == 2 ){
    #Since we can't simply pass @_ through due to open's prototype,
    #we might as well convert to 3-arg

    if( $mode =~ /^\s*
		  (
		   \|       |         #pipe-out
	           (?:\>{1,2}|<)&=?|  #dup & fdopen
		   \+?>{1,2}|         #write, append, write-read, append-read
                   \+?<               #read, read-write
		  )?
		  \s*
		  (.+?)               #the beef
		  \s*
		  (\|)?               #pipe-in
		  \s*
		  $/x ){
      ($testmode, $file, $pipein) = ($1||'', $2||'', $3||'');
      #if it's a 2-arg dup and we're a stale perl, just do it & return;
      return CORE::open($handle, $mode) if $[ < 5.008 &&
                                     $mode =~ /^\s*(?:\>{1,2}|<)&=?/;
    }
    else{
      croak "Failed to parse EXPR of 2-arg open: $_[1]";
    }

    $testmode = $testmode eq '|' ? '|-' : $testmode;
    unless( length $testmode ){
      $testmode = $pipein ? '-|' : 
                  $file eq '-' ? '<' : '>';
    }
  }
  elsif( scalar(@_) > 2 ){
    ($testmode, $file) = @_[1,2];
  }

  prompt($file, $scope) if -e $file && $testmode =~ /$stricture/;

  splice(@_, 0, 3);

  #no strict 'refs';
  CORE::open(*{caller(0) . '::' . $handle}, $testmode, $file, @_);
}

sub SYSOPEN(*$$;$){
  my($handle, $file, $mode, $perms) = @_;
  my $scope = (caller 0)[10];

  my $stricture = $scope->{'clobber-lax'} ? O_TRUNC : (O_WRONLY|O_RDWR|O_TRUNC);

  #We don't use O_EXCL because sysopen's failure is not trappable
  prompt($file, $scope) if -e $file && $mode&$stricture;

  #no strict 'refs';
  CORE::sysopen(*{caller(0) . '::' . $handle}, $file, $mode, $perms||0666);
}

sub RENAME($$){
  my $scope = (caller 0)[10];

  prompt($_[1], $scope, "$_[0]: overwrite `$_[1]'?") if -e $_[1];

  CORE::rename($_[0], $_[1]);
}

sub prompt{
  my $clobber = 0;

  return if $_[1]->{'clobber'};

  if( -t STDIN && exists($INC{'Term/ReadKey.pm'}) ){

    select(STDERR); local $|=1;
    print STDERR  ($_[2] || "Allow modification of '$_[0]'?") . ' [yN] ';

    Term::ReadKey::ReadMode('cbreak'); $clobber = Term::ReadKey::ReadKey(0);

    Term::ReadKey::ReadMode('restore'); print STDERR "\n";

    $clobber =~ y/yY/1/; $clobber =~ y/1/0/c;
  }

  croak "$_[0]: File exists" unless $clobber;
}


1;
__END__

=pod

=head1 NAME

clobber - pragma to optionally prevent over-writing files

=head1 SYNOPSIS

  BEGIN{ no clobber }

  #These fail if /tmp/xyzzy exists
      open(HNDL, '>   /tmp/xyzzy');
  #   open(HNDL, '>', /tmp/xyzzy');
  #sysopen(HNDL,     '/tmp/xyzzy', O_WRONLY|O_CREAT);

  #It's clobberin' time
  do{
    use clobber; open(HNDL, '>/tmp/xyzzy');
  }

=head1 DESCRIPTION

Do you occasionally get I<+E<gt>> and I<+E<lt>> mixed up, or accidentally
leave off an I<E<gt>> in the mode of an C<open>? Want to run some relatively
trustworthy code--such as some spaghetti monster you created in the days
of yore--but can't be bothered to check it's semantics? Or perhaps you'd
like to add a level of protection to operations on user-supplied files
without coding the logic yourself.

Yes? Then this pragma could help you from blowing away valuable data,
similar to the B<noclobber> variable of some shells or B<-i> option of
C<mv>. This behavior can be controlled at the block level, as demonstrated
in the L</SYNOPSIS>.

All modes restrict C<rename> to mimic the B<-i> option of C<mv>.

If a backup extension is not supplied for perl's C<-i>nplace edit mode,
it is set to I<~>

The protections afforded to C<open> and <sysopen> are configurable:

=head2 Default protection

This includes modes that truncate or allow modification of data.

=over

=item C<open>

I<E<gt>> | I<+E<gt>> | I<+E<lt>>

=item C<sysopen>

I<O_WRONLY> | I<O_RDWR> | I<O_TRUNC>

=back

=head2 Lax protection

This only includes modes that explicitly truncate.

=over

=item C<open>

B<E<gt>> | B<+E<gt>>

=item C<sysopen>

B<O_TRUNC>

=back

You may loosen clobber's reigns by passing B<:lax> to (un)import,
for a usage similar similar to strict:

  no clobber;
  ...
  {
    use clobber ':lax';
    ...
  }

=head1 DIAGNOSTICS

The pragma may throw the following exceptions:

=over

=item %s: File exists

We saved data!

=item Failed to parse EXPR of 2-arg open: %s

The pragma could not figure out what mode was used,
and decided to bail for safety.

This shouldn't happen.

=back

=head1 ENVIRONMENT

You may disable clobber protection at compile-time by setting the environment
variable I<clobber.pm> to 1. This allows you to include F<clobber.pm> in
I<PERL5OPT> as B<-M-clobber> for general protection, but override it as needed
for programs invoked via a pipeline.

=head1 CAVEATS

As noted in the L</DESCRIPTION>, this is meant to be used with code which
is generally believed to be safe, and is a layer of protection against human
error, not malicious intent. I know it could have prevented many
1-liner-enabled, self-inflicted gunshot wounds of the foot in the past.

Any number of other actions could result in data loss including the invocation
of external programs via pipe-C<opens>, C<qx>, or C<system> (with or without
shell redirection) and calls to fuctions implemented in XS.

=head1 NOTES

Requires Perl 5.6 or higher. the basic premise could be implemented in 5.005,
but we translate (nearly) every 2-arg open to 3-arg for
'simplicity'/safety/shits-n-giggles; the exceptions are dups and fdopens for
Perl 5.6, where 3-arg open doesn't grok these modes.

=head1 TODO

=over

=item Tests

If interactive ask to run the more complex tests, with timeout to skip the
initial query.

=item B<:quiet> mode to continue despite failed command?

Not by default. Other bad things may happen if a filehandle is not available,
but file renaming may be okay. Should it threfore default to carp?

=item wrap other data-damaging functions in a B<:strict> mode?

e.g; F<truncate>, F<unlink>, and calls to external commands.

=back

=head1 AUTHOR

Jerrad Pierce E<lt>JPIERCE circle-a CPAN full-stop ORGE<gt>

=head1 LICENSE

=over

=item * Thou shalt not claim ownership of unmodified materials.

=item * Thou shalt not claim whole ownership of modified materials.

=item * Thou shalt grant the indemnity of the provider of materials.

=item * Thou shalt use and dispense freely without other restrictions.

=back

Or, if you prefer:

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

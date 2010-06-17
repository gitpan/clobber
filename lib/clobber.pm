package clobber;
use Carp;
use strict; no strict 'refs';
use vars '$VERSION'; $VERSION = 0.02;

sub unimport { #no strict 'refs';
  *{'CORE::GLOBAL::open'} = \&customopen unless exists($^H{clobber});
  $^H{clobber} = $ENV{'clobber.pm'} || 0;
}

sub import {
  $^H{clobber} = 1;
}


sub customopen(*;$@){
  my($handle, $mode, $file) = @_;
  my($testmode, $pipein) = $mode;

  if( scalar(@_) == 1 ){ #no strict 'refs';
    $mode = ${caller(1).'::'.$handle};
  }

  if( scalar(@_) == 2 ){
    #Convert 2-arg to 3-arg...
    #Initially tried to simply pass @_ through to CORE::open,
    #but it's prototype didn't like that

    #put into sub for /x, and easier "testing"?
    if( $mode =~ /^(\+?(?:>{1,2}|<)|(?:>&=?|<&=?|\|))?\s*(.+)\s*(\|)?$/ ){
      ($testmode, $file, $pipein) = ($1, $2, $3);
    }
    else{
      croak "Failed to parse EXPR of 2-arg open: $_[1]";
    }

    $testmode = $1 eq '|' ? '|-' : $1;
    unless( defined $testmode ){
      $testmode = $pipein ? '-|' : '>';
    }
  }
  elsif( scalar(@_) > 2 ){
    ($testmode, $file) = @_[1,2];
  }

  if( !(caller 0)[10]->{clobber} && -e $file &&
      $testmode =~ /\+[<>](?!>)|^>(?!&|>)/ ){
    croak "$file: File exists.";
  }

  splice(@_, 0, 3);

  #no strict 'refs';
  CORE::open(*{caller(0) . '::' . $handle}, $testmode, $file, @_);
}

1;
__END__
               As a special case the 3-arg form with a read/write mode and the
               third argument being "undef":

=pod

=head1 NAME

clobber - pragma to optionally prevent over-writing files

=head1 SYNOPSIS

  no clobber;

  #Fails if /tmp/xyzzy exists
  open(HNDL, '>/tmp/xyzzy');

  {
    use clobber;

    #It's clobberin' time
    open(HNDL, '>/tmp/xyzzy');
  }

=head1 DESCRIPTION

Do you occasionally get C<+E<gt>> and C<+E<lt>> mixed up, or accidentally
leave off an E<gt> in the mode of an C<open>? Want to run some relatively
trustworthy code--such as some spaghetti monster you created in the days
of yore--but can't be bothered to check it's semantics? Then this pragma
could help you from blowing away valuable data.

Like the I<noclobber> variable of some shells, this module will prevent
the use of open modes which truncate if a file already exists. This behavior
can be controlled at the block level, as demonstrated in the L</SYNOPSIS>.

=head1 DIAGNOSTICS

The pragma may throw the following exceptions:

=over

=item %s: File exists.

We saved data!

=item Failed to parse EXPR of 2-arg open: %s

The module could not figure out what mode was used,
and decided to bail for safety.

This shouldn't happen.

=back

=head1 ENVIRONMENT

You may disable clobber protection at compile-time by setting the environment
variable I<clobber.pm> to 1. This allows you to include F<clobber.pm> in
I<PERL5OPT> as B<-M-clobber> for general protection, but override it as needed
for programs invoked via a pipeline.

=head1 TODO

=over

=item TESTS!

I've done some basic-testing with 2- and 3-arg forms of read/write/append,
but more thorough testing of mode-parsing and/or invocation needs to be done.

Interactive ask to run the more complex tests, with timeout to skip them.

=item interactive mode

Prompt for permission to clobber with Term::ReadKey

=item sysopen

Should be easier? No parsing, just twiddle the bits of bad modes

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

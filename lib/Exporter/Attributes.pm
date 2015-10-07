use strict;
use warnings FATAL => 'all';

package Exporter::Attributes;

# ABSTRACT: Export symbols by attributes

use Exporter 5.72 ();
use Attribute::Universal
  Exportable => 'ANY,BEGIN',
  Exported   => 'ANY,BEGIN';
use Carp qw(croak);

# VERSION

our @EXPORT_OK = qw(import);

my $symbols = {};

my %lists = (
  Exportable => 'export_ok',
  Exported   => 'export',
);

my %sigil = (
  SCALAR => '$',
  ARRAY  => '@',
  HASH   => '%',
  CODE   => '&',
);

sub add {
  my ($package, $list, $name, $data) = @_;
  $symbols->{$package} //= {
    export => [],
    export_ok => [],
    export_tags => {},
  };
  push @{ $symbols->{$package}->{$list} } => $name;
  return unless $data;
  my @tags = map { split /[\s,]+/ } @$data;
  foreach my $tag (@tags) {
    push @{ $symbols->{$package}->{export_tags}->{$tag} } => $name;
  }
}

use namespace::clean;

=for Pod::Coverage ATTRIBUTE
=cut

sub ATTRIBUTE {
  my ($package, $symbol, $referent, $attribute, $payload, $phase, $file, $line) = @_;
  croak("lexical symbols are not exportable, in $file at line $line") unless ref $symbol;
  # $label is the name of the subroutine or variable
  my $label = *{$symbol}{NAME};
  my $type  = ref $referent;
  my $sigil = $sigil{$type};
  my $list  = $lists{$attribute};
  add($package, $list, $sigil . $label, $payload);
}

sub import {
  my $class = $_[0];
  
  # export our own "import" method into the caller class
  # so abort here if "import" is called by "use Exporter::Attributes"
  goto &Exporter::import if $class eq __PACKAGE__;
  
  # get export symbols or just return
  my $_symbols = $symbols->{$class} // return;
  
  # build :all export tag by concat @EXPORT and @EXPORT_OK
  $_symbols->{export_tags}->{all} = [
    @{ $_symbols->{export} },
    @{ $_symbols->{export_ok} },
  ];
  
  # this is a quite easy way to say "our @Class::EXPORT", which is normally not possible
  # we are rewriting the symbol table, dont let strict concern about it!
  no strict 'refs'; ## no critic
  *{"${class}::EXPORT"} = $_symbols->{export};
  *{"${class}::EXPORT_OK"} = $_symbols->{export_ok};
  *{"${class}::EXPORT_TAGS"} = $_symbols->{export_tags};
  
  # and finally let import the symbol into the caller namespace.
  goto &Exporter::import;
}

1;

=head1 SYNOPSIS

    package FooBar;
    
    use Exporter::Attributes qw(import);
    
    sub Foo : Exported;
    sub Bar : Exportable;
    
    our $Cat : Exportable(vars);
    our $Dog : Exportable(vars);
    
    package main;
    
    use FooBar;           # imports &Foo
    use FooBar qw(Bar);   # import &Bar
    use FooBar qw(:vars); # import $Cat and $Dog
    use FooBar qw(:all);  # import &Foo, &Bar, $Cat and $Dog

=head1 DESCRIPTION

This module is inspired by L<Exporter::Simple>, but that is module broken since a long time. The new implementation uses a smarter way, by rewriting the caller's symbol table then and goto L<Exporter/import>.

The list the export symbols are captured with L<attributes>. There are two attributes:

=over 4

=item * I<Exported>

Which adds the name of the symbol to C<@EXPORT>

=item * I<Exportable>

Which adds the name of the symbol to C<EXPORT_OK>

=back

The attributes accepts a list of tags as argument.

=func import

This is an ambivalent function. When called as C<< Export::Attributes->import >> it just imports this L</import> function into the namespace of the caller.

When called from any other class, it rewrites C<@EXPORT>, C<@EXPORT_OK> and C<@EXPORT_TAGS> and let the rest of the work done by L<Exporter>.

=head1 TESTS

The tests in this distribution are copied from L<Exporter::Simple>.


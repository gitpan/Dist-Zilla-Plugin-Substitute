package Dist::Zilla::Plugin::Substitute;
{
  $Dist::Zilla::Plugin::Substitute::VERSION = '0.003';
}

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw/ArrayRef CodeRef/;

with qw/Dist::Zilla::Role::FileMunger/;

has finders => (
	is  => 'ro',
	isa => 'ArrayRef',
	default => sub { [ qw/:InstallModules :ExecFiles/ ] },
);

my $codeliteral = subtype as CodeRef;
coerce $codeliteral, from ArrayRef, via { eval sprintf "sub { %s } ", join "\n", @{ $_ } };

has code => (
	is       => 'ro',
	isa      => $codeliteral,
	coerce   => 1,
	required => 1,
);
has filename_code => (
	is       => 'ro',
	isa      => $codeliteral,
	coerce   => 1,
	predicate => '_has_filename_code',
);

sub mvp_multivalue_args {
	return qw/finders code filename_code/;
}
sub mvp_aliases {
	return { content_code => 'code' };
}

sub files {
	my $self = shift;
	my @filesets = map { @{ $self->zilla->find_files($_) } } @{ $self->finders };
	my %files = map { $_->name => $_ } @filesets;
	return values %files;
}

sub munge_files {
	my $self = shift;
	$self->munge_file($_) for $self->files;
	return;
}

sub munge_file {
	my ($self, $file) = @_;
	my @content = split /\n/, $file->content;
	my $code = $self->code;
	$code->() for @content;
	$file->content(join "\n", @content);

	if ($self->_has_filename_code) {
		my $filename = $file->name;
		my $filename_code = $self->filename_code;
		$filename_code->() for $filename;
		$file->name($filename);
	}

	return;
}

1;

# ABSTRACT: Substitutions for files in dzil

__END__

=pod

=head1 NAME

Dist::Zilla::Plugin::Substitute - Substitutions for files in dzil

=head1 VERSION

version 0.003

=head1 SYNOPSIS

 [Substitute]
 finder = :ExecFiles
 code = s/Foo/Bar/g
 filename_code = s/foo\.pl/bar.pl/

=head1 DESCRIPTION

This module performs substitutions on files in Dist::Zilla.

=head1 ATTRIBUTES

=head2 code (or content_code)

An arrayref of lines of code. This is converted into a sub that's called for each line, with C<$_> containing that line. Alternatively, it may be a subref if passed from for example a pluginbundle. Mandatory.

=head2 filename_code

Like C<content_code> but the resulting sub is called for the filename.
Optional.

=head2 finders

The finders to use for the substitutions. Defaults to C<:InstallModules, :ExecFiles>.

# vi:noet:sts=2:sw=2:ts=2

=head1 AUTHOR

Leon Timmermans <leont@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

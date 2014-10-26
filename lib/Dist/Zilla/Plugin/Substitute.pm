package Dist::Zilla::Plugin::Substitute;
{
  $Dist::Zilla::Plugin::Substitute::VERSION = '0.004';
}

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw/ArrayRef CodeRef/;

use Carp 'croak';

with qw/Dist::Zilla::Role::FileMunger/;

has finders => (
	is      => 'bare',
	isa     => 'ArrayRef',
	default => sub { [qw/:InstallModules :ExecFiles/] },
	traits  => ['Array'],
	handles => {
		finders => 'elements',
	},
);

my $codeliteral = subtype as CodeRef;
coerce $codeliteral, from ArrayRef, via {
	my $code = sprintf 'sub { %s } ', join "\n", @{$_};
	eval $code or croak "Couldn't eval: $@";
};

has code => (
	is       => 'ro',
	isa      => $codeliteral,
	coerce   => 1,
	required => 1,
);
has filename_code => (
	is        => 'ro',
	isa       => $codeliteral,
	coerce    => 1,
	predicate => '_has_filename_code',
);

sub mvp_multivalue_args {
	return qw/finders code filename_code files/;
}

sub mvp_aliases {
	return {
		content_code => 'code',
		finder       => 'finders',
		file         => 'files',
	};
}

has files => (
	is      => 'bare',
	isa     => ArrayRef,
	builder => '_build_files',
	traits  => ['Array'],
	lazy    => 1,
	handles => {
		files => 'elements',
	},
);

sub _build_files {
	my $self     = shift;
	my @filesets = map { @{ $self->zilla->find_files($_) } } $self->finders;
	my %files    = map { $_->name => $_ } @filesets;
	return [ values %files ];
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
		my $filename      = $file->name;
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

version 0.004

=head1 SYNOPSIS

 [Substitute]
 finder = :ExecFiles
 code = s/Foo/Bar/g
 
 ; alternatively
 [Substitute]
 file = lib/Buz.pm
 code = s/Buz/Quz/g
 filename_code = s/Buz/Quz/

=head1 DESCRIPTION

This module performs substitutions on files in Dist::Zilla.

=head1 ATTRIBUTES

=head2 code (or content_code)

An arrayref of lines of code. This is converted into a sub that's called for each line, with C<$_> containing that line. Alternatively, it may be a subref if passed from for example a pluginbundle. Mandatory.

=head2 filename_code

Like C<content_code> but the resulting sub is called for the filename.
Optional.

=head2 finders

The finders to use for the substitutions. Defaults to C<:InstallModules, :ExecFiles>. May also be spelled as C<finder> in the dist.ini.

=head2 files

The files to substitute. It defaults to the files in C<finders>. May also be spelled as C<file> in the dist.ini.

# vi:noet:sts=2:sw=2:ts=2

=head1 AUTHOR

Leon Timmermans <leont@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

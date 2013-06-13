package Bio::Pipeline::Comparison::Generate::VCFWriter;

# ABSTRACT: Create a VCF with the differences between a reference and a single evolved genome. Outputs a gzipped VCF file and a tabix file.

=head1 SYNOPSIS

Create a VCF with the differences between a reference and a single evolved genome

    use Bio::Pipeline::Comparison::Generate::VCFWriter;
    my $obj = Bio::Pipeline::Comparison::Generate::VCFWriter->new(output_filename => 'my_snps.vcf.gz');
    $obj->add_snp(1234, 'C', 'A', 'Chr1');
    $obj->add_snp(1234, 'T', 'A', 'Chr1'));
    $obj->create_file();

=method add_snp

Stage a base position in the reference genome, the reference base and a new base for writing to the VCF file.

=method create_file

Create the VCF file and gzip it. Create an index for the file using tabix.

=method evolved_name

Optional input parameter. This is the name that goes in the column of the VCF file. The output filename is used as the base for this name by default.

=head1 SEE ALSO

=for :list
* L<Bio::Pipeline::Comparison>

=cut

use Moose;
use File::Basename;
use Bio::Pipeline::Comparison::Types;
use Vcf;

has 'output_filename' => ( is => 'ro', isa => 'Str', required => 1 );
has 'evolved_name'    => ( is => 'ro', isa => 'Str', lazy => 1, builder => '_build_evolved_name' );

has '_output_fh' => ( is => 'ro', lazy => 1, builder => '_build_output_fh' );
has '_vcf'       => ( is => 'ro', isa => 'Vcf', lazy => 1, builder => '_build__vcf' );
has '_vcf_lines' => ( is => 'ro', isa => 'ArrayRef', default => sub { [] } );

has 'bgzip_exec' => ( is => 'ro', isa => 'Bio::Pipeline::Comparison::Executable', default => 'bgzip' );
has 'tabix_exec' => ( is => 'ro', isa => 'Bio::Pipeline::Comparison::Executable', default => 'tabix' );

sub _build_output_fh {
    my ($self) = @_;
    open( my $output_fh, '|-', $self->bgzip_exec." -c > " . $self->output_filename );
    return $output_fh;
}

sub _build__vcf {
    my ($self) = @_;
    Vcf->new();
}

sub _build_evolved_name {
    my ($self) = @_;
    my $evolved_name = $self->output_filename;
    $evolved_name =~ s!.vcf.gz!!i;
    my ( $base_filename, $directories, $suffix ) = fileparse( $evolved_name, qr/\.[^.]*/ );
    return $base_filename;
}

sub _construct_header {
    my ($self) = @_;

    # Get the header of the output VCF ready
    $self->_vcf->add_columns( ( $self->evolved_name ) );
    print { $self->_output_fh } ( $self->_vcf->format_header() );
}

sub _create_index {
    my ($self) = @_;
    my $cmd = join(' ',($self->tabix_exec, "-p vcf", "-f",$self->output_filename));
    system($cmd);
}


sub add_snp {
    my ( $self, $position, $reference_base, $base, $chromosome ) = @_;
    
    #position here should be from the evolved reference (update when indels included).
    my %snp;
    $snp{POS}    = $position +1;
    $snp{ALT}    = [$reference_base];
    $snp{REF}    = $base;
    $snp{ID}     = '.';
    $snp{CHROM}  = $chromosome;
    $snp{QUAL}   = 1;

    push( @{ $self->_vcf_lines }, \%snp );
}

sub create_file {
    my ($self) = @_;
    $self->_construct_header;

    for my $vcf_line ( @{ $self->_vcf_lines } ) {
        print { $self->_output_fh } ( $self->_vcf->format_line($vcf_line) );
    }
    close($self->_output_fh );
    $self->_create_index();
    1;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

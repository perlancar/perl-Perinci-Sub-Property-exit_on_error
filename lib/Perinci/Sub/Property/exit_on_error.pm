package Perinci::Sub::Property::exit_on_error;

use 5.010001;
use strict;
use warnings;
#use Log::Any '$log';

use Perinci::Sub::PropertyUtil qw(declare_property);

# VERSION

declare_property(
    name => 'exit_on_error',
    type => 'function',
    schema => ['any*' => {of=>[
        ['bool' => {default=>0}],
        ['hash*' => {keys=>{
            'success_statuses'   => ['regex' => {default=>'^(2..|304)$'}],
        }}],
    ]}],
    wrapper => {
        meta => {
            v       => 2,
            prio    => 99, # very low, the last to do stuff to $_w_res
            convert => 1,
        },
        handler => sub {
            my ($self, %args) = @_;
            my $v    = $args{new} // $args{value} // 0;
            my $meta = $args{meta};

            return unless $v;

            die "Cannot use exit_on_error if result_naked is 1"
                if $self->{_meta}{result_naked};

            $v = {} if ref($v) ne 'HASH';

            $v->{success_statuses} //= qr/^(2..|304)$/;

            for my $k (qw/success_statuses/) {
                if (defined($v->{$k}) && ref($v->{$k}) ne 'Regexp') {
                    $v->{$k} = qr/$v->{$k}/;
                }
            }

            $self->select_section('after_eval');

            $self->push_lines('if ($_w_eval_err) { die $_w_eval_err }');

            $self->push_lines('if ($_w_res->[0] !~ /'.$v->{success_statuses}.'/) {');
            $self->indent;
            $self->push_lines(join(
                "",
                "warn 'Call to ",
                ($self->{_args}{sub_name} ? "$self->{_args}{sub_name}()" : "function"),
                q[ returned non-success status '. "$_w_res->[0]: $_w_res->[1]";]));
            $self->push_lines('exit($_w_res->[0]-300);');
            $self->unindent;
            $self->push_lines('}');
        },
    },
);

1;
# ABSTRACT: Die on non-success result

=head1 SYNOPSIS

Without exit_on_error:

 # on successful call
 f(...); # [200, "OK"]

 # on non-successful call
 f(...); # [404, "Not found"]

With C<< exit_on_error => 1 >>:

 # on successful call
 f(...); # [200, "OK"]

 # on non-successful call
 f(...); # print message "Call f() failed with 404 status: Not found" to STDERR and exits 104

To customize what statuses are considered error: C<< exit_on_error => {
success_statuses => '^2..$' } >>.


=head1 DESCRIPTION

This property sets so that function calls C<exit()> when result status is a
non-successful one. Successful statuses by default include 2xx and 304 (C<<
'^(2..|304)$' >>).

Exit code is currently set to (like in L<Perinci::CmdLine>) and might be
customizable in the future.


=head1 SEE ALSO

L<Perinci>

=cut

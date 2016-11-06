#
# Copyright 2016 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package cloud::docker::mode::nodestate;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $thresholds = {
    state => [
        ['ready', 'OK'],
        ['disconnected', 'WARNING'],
        ['down', 'CRITICAL'],
        ['unknown', 'UNKNOWN'],
    ],
};

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
        {
            "port:s"                 => { name => 'port' }, 
            "id:s"                   => { name => 'id' },
            "threshold-overload:s@"  => { name => 'threshold_overload' },
        });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if ((defined($self->{option_results}->{id})) && ($self->{option_results}->{id} eq '')) {
        $self->{output}->add_option_msg(short_msg => "You need to specify the id option");
        $self->{output}->option_exit();
    }

    $self->{overload_th} = {};
    foreach my $val (@{$self->{option_results}->{threshold_overload}}) {
        if ($val !~ /^(.*?),(.*?),(.*)$/) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload option '" . $val . "'.");
            $self->{output}->option_exit();
        }
        my ($section, $status, $filter) = ($1, $2, $3);
        if ($self->{output}->is_litteral_status(status => $status) == 0) {
            $self->{output}->add_option_msg(short_msg => "Wrong threshold-overload status '" . $val . "'.");
            $self->{output}->option_exit();
        }
        $self->{overload_th}->{$section} = [] if (!defined($self->{overload_th}->{$section}));
        push @{$self->{overload_th}->{$section}}, {filter => $filter, status => $status};
    }
}

sub get_severity {
    my ($self, %options) = @_;
    my $status = 'UNKNOWN'; # default

    if (defined($self->{overload_th}->{$options{section}})) {
        foreach (@{$self->{overload_th}->{$options{section}}}) {
            if ($options{value} =~ /$_->{filter}/i) {
                $status = $_->{status};
                return $status;
            }
        }
    }
    foreach (@{$thresholds->{$options{section}}}) {
        if ($options{value} =~ /$$_[0]/i) {
            $status = $$_[1];
            return $status;
        }
    }
    return $status;
}

sub run {
    my ($self, %options) = @_;

    my $urlpath = "/nodes/".$self->{option_results}->{id};
    my $port = $self->{option_results}->{port};
    my $nodeapi = $options{custom};

    my $webcontent = $nodeapi->api_request(urlpath => $urlpath,
                                            port => $port);

	my $exit  = $self->get_severity(section => 'state', value => $webcontent->{Status}->{State});

	if (defined($webcontent->{ManagerStatus}->{Reachability})) {
		$self->{output}->output_add(severity => $exit,
									short_msg => sprintf("%s node is %s (Availability: %s - Reachability: %s)",
														$webcontent->{Spec}->{Role},
														$webcontent->{Status}->{State},
														$webcontent->{Spec}->{Availability},
														$webcontent->{ManagerStatus}->{Reachability}));
	} else {
		$self->{output}->output_add(severity => $exit,
                                    short_msg => sprintf("%s node is %s (Availability: %s)",
                                                        $webcontent->{Spec}->{Role},
                                                        $webcontent->{Status}->{State},
                                                        $webcontent->{Spec}->{Availability}));
	}

    $self->{output}->display();
    $self->{output}->exit();

}

1;

__END__

=head1 MODE

Check Swarm Node's state

=head2 DOCKER OPTIONS

item B<--port>

Port used by Docker

=item B<--id>

Specify one node's id

=head2 MODE OPTIONS

=item B<--threshold-overload>

Set to overload default threshold values (syntax: section,status,regexp)
It used before default thresholds (order stays).
Example: --threshold-overload='state,CRITICAL,^(?!(disconnected)$)'

=back

=cut

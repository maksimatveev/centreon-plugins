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

package network::huawei::standard::snmp::mode::cpu;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '0.2';
    $options{options}->add_options(arguments =>
                                {
                                  "warning:s"               => { name => 'warning', default => '' },
                                  "critical:s"              => { name => 'critical', default => '' },
                                });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    ($self->{warnavg}, $self->{warn1m}, $self->{warn5m}) = split /,/, $self->{option_results}->{warning};
    ($self->{critavg}, $self->{crit1m}, $self->{crit5m}) = split /,/, $self->{option_results}->{critical};
    
    if (($self->{perfdata}->threshold_validate(label => 'warnavg', value => $self->{warnavg})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong warning (average) threshold '" . $self->{warnavg} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warn1m', value => $self->{warn1m})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong warning (1min) threshold '" . $self->{warn1m} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warn5m', value => $self->{warn5m})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong warning (5min) threshold '" . $self->{warn5m} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critavg', value => $self->{critavg})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong critical (average) threshold '" . $self->{critavg} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'crit1m', value => $self->{crit1m})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong critical (1min) threshold '" . $self->{crit1m} . "'.");
       $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'crit5m', value => $self->{crit5})) == 0) {
       $self->{output}->add_option_msg(short_msg => "Wrong critical (5min) threshold '" . $self->{crit5m} . "'.");
       $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};

    my $oid_hwCpuDevDuty = '.1.3.6.1.4.1.2011.6.3.4.1.2.0';
    #The value of this object identifies the average CPU occupancy of a board or an entity.
    my $oid_hwAvgDuty1min = '.1.3.6.1.4.1.2011.6.3.4.1.3.0';
    #The value of this object identifies the average CPU occupancy of a board or an entity in the last one minute before you access the object.
    my $oid_hwAvgDuty5min = '.1.3.6.1.4.1.2011.6.3.4.1.4.0';
    #The value of this object identifies the average CPU occupancy of a board or an entity in the last five minutes before you access the object.
   
    $self->{result} = $self->{snmp}->get_leef(oids => [ $oid_hwCpuDevDuty, $oid_hwAvgDuty1min, $oid_hwAvgDuty5min],
                                              nothing_quit => 1);
    
    my $cpuavg = $self->{result}->{$oid_hwCpuDevDuty};
    my $cpu1min = $self->{result}->{$oid_hwAvgDuty1min};
    my $cpu5min = $self->{result}->{$oid_hwAvgDuty5min};
    
    my $exit1 = $self->{perfdata}->threshold_check(value => $cpuavg, 
                           threshold => [ { label => 'critavg', exit_litteral => 'critical' }, { label => 'warnavg', exit_litteral => 'warning' } ]);
    my $exit2 = $self->{perfdata}->threshold_check(value => $cpu1min, 
                           threshold => [ { label => 'crit1m', exit_litteral => 'critical' }, { label => 'warn1m', exit_litteral => 'warning' } ]);
    my $exit3 = $self->{perfdata}->threshold_check(value => $cpu5min, 
                           threshold => [ { label => 'crit5m', exit_litteral => 'critical' }, { label => 'warn5m', exit_litteral => 'warning' } ]);
    my $exit = $self->{output}->get_most_critical(status => [ $exit1, $exit2, $exit3 ]);
    
    $self->{output}->output_add(severity => $exit,
                                short_msg => sprintf("CPU Usage: %.2f%% (avg), %.2f%% (1min), %.2f%% (5min)",
                                                    $cpuavg, $cpu1min, $cpu5min));
    
    $self->{output}->perfdata_add(label => "cpu_avg", unit => '%',
                                  value => $cpuavg,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warnavg'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'warnavg'),
                                  min => 0, max => 100);
    $self->{output}->perfdata_add(label => "cpu_1m", unit => '%',
                                  value => $cpu1min,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warn1m'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'crit1m'),
                                  min => 0, max => 100);
    $self->{output}->perfdata_add(label => "cpu_5m", unit => '%',
                                  value => $cpu5min,
                                  warning => $self->{perfdata}->get_perfdata_for_output(label => 'warn5m'),
                                  critical => $self->{perfdata}->get_perfdata_for_output(label => 'crit5m'),
                                  min => 0, max => 100);
    
    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check CPU usage (HUAWEI-CPU-MIB).

=over 8

=item B<--warning>

Threshold warning in percent (avg,1min,5min).

=item B<--critical>

Threshold critical in percent (avg,1min,5min).

=back

=cut
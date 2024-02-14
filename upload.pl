use strict;
use v5.28;

use lib "/home/pi";
use rt5645_regs;
use upload_regs;

use Device::I2C;

my $bus;

sub init_i2c {
  $bus = Device::I2C->new('/dev/i2c-1', Device::I2C::O_RDWR);
}

sub snd_soc_component_write {
  my ($device, $reg, $val) = @_;
  $bus->selectDevice($device);
  $bus->writeWordData($reg, swap_bytes($val));
  return 1;
}

sub swap_bytes {
  my $input = shift;
  return ($input & 0xff) << 8 | $input >> 8;
}


my $mode = $ARGV[0];
print("Mode should be play or record or null\n");
my %regs_mx = %combined_mx;
my %regs_pr = %combined_pr;
if ($mode eq "play") {
  %regs_mx = %play_mx;
  %regs_pr = %play_pr;
  print("Mode is play\n");
}
if ($mode eq "record") {
  %regs_mx = %record_mx;
  %regs_pr = %record_pr;
  print("Mode is record\n");
}


init_i2c();

snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_RESET, 0);
sleep(1);

# try using setup from rt5645/init as well

foreach my $reg (sort keys %regs_mx) {
  snd_soc_component_write($RT5645_I2C_ADDR, $reg, $record_mx{$reg});
}

foreach my $reg (sort keys %regs_pr) {
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_INDEX, $reg);
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_DATA, $record_pr{$reg});
}

print("\n\n");

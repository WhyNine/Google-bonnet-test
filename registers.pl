use strict;
use v5.28;

use lib "/home/pi";
use rt5645_regs;

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

sub snd_soc_component_read {
  my ($device, $reg) = @_;
  $bus->selectDevice($device);
  return swap_bytes($bus->readWordData($reg));
}

sub swap_bytes {
  my $input = shift;
  return ($input & 0xff) << 8 | $input >> 8;
}


init_i2c();

foreach my $reg (0 .. 0xff) {
  my $val = snd_soc_component_read($RT5645_I2C_ADDR, $reg);
  printf("  0x%x => 0x%x,\n", $reg, $val);
}

print("\n\n");

foreach my $reg (0 .. 0xff) {
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_INDEX, $reg);
  my $val = snd_soc_component_read($RT5645_I2C_ADDR, $RT5645_PRIV_DATA);
  printf("  0x%x => 0x%x,\n", $reg, $val);
}

print("\n\n");

package misc;

use v5.28;

our @EXPORT = qw ( snd_soc_component_update_bits init_i2c gcd snd_soc_component_write snd_soc_component_read snd_soc_dai_set_sysclk msleep i2c_read i2c_write );
use base qw(Exporter);


use strict;

use lib "/home/pi";

use Device::I2C;
use Fcntl;
use Time::HiRes qw( usleep );

my $bus;

sub init_i2c {
  $bus = Device::I2C->new('/dev/i2c-1', O_RDWR);
}

sub msleep {
  my $val = shift;
  usleep($val * 1000);
}

sub swap_bytes {
  my $input = shift;
  return ($input & 0xff) << 8 | $input >> 8;
}

#/**
# * snd_soc_component_update_bits() - Perform read/modify/write cycle
# * @device: Device to update
# * @reg: Register to update
# * @mask: Mask that specifies which bits to update
# * @val: New value for the bits specified by mask
# * @word: If 1, then updating a word else a byte
# *
# * Return: 1 if the operation was successful and the value of the register
# * changed, 0 if the operation was successful, but the value did not change.
# */
sub snd_soc_component_update_bits {
  my ($device, $reg, $mask, $val) = @_;
  printf("update reg %x with value %x and mask %x\n", $reg, $val, $mask);
  $mask = swap_bytes($mask);
  $val = swap_bytes($val);
  $bus->selectDevice($device);
  my $value = $bus->readWordData($reg);               # may have to use readNByte instead
  $value = ($value & ~$mask) | ($val & $mask);
  $bus->writeWordData($reg, $value);
  return $bus->readWordData($reg) == $value;
}

#/**
# * snd_soc_component_write() - Write register value
# * @component: Component to write to
# * @reg: Register to write
# * @val: Value to write to the register
# *
# * Return: 0 on success, a negative error code otherwise.
# */
sub snd_soc_component_write {
  my ($device, $reg, $val) = @_;
  printf("write reg %x with value %x\n", $reg, $val);
  $bus->selectDevice($device);
  $bus->writeWordData($reg, swap_bytes($val));
  return 1;
}

#/**
# * snd_soc_component_read() - Read register value
# * @component: Component to read from
# * @reg: Register to read
# *
# * Return: read value
# */
sub snd_soc_component_read {
  my ($device, $reg) = @_;
  $bus->selectDevice($device);
  return swap_bytes($bus->readWordData($reg));
}

# gretest common denominator
sub gcd {
  my ($a, $b) = @_;
  ($a,$b) = ($b,$a) if $a > $b;
  while ($a) {
    ($a, $b) = ($b % $a, $a);
  }
  return $b;
}

sub i2c_read {
  my ($device, $reg) = @_;
  $bus->selectDevice($device);
  return $bus->readByteData($reg);
}

sub i2c_write {
  my ($device, $reg, $val) = @_;
  printf("write reg %x with value %x\n", $reg, $val);
  $bus->selectDevice($device);
  $bus->writeByteData($reg, $val);
  return 1;
}


1;

use strict;
use v5.28;

use lib "/home/pi";
use misc;

my $ktd2026_addr = 0x31;                    # note that registers are write only
my $control = 0;
my $led_enable = 4;
my $led_on = 1;
my $led_off = 0;
my $led_on_drive = 0x80;
my $red_ctrl_bits = 0;
my $green_ctrl_bits = 2;
my $blue_ctrl_bits = 4;
my $led_red = 6;
my $led_green = 7;
my $led_blue = 8;

sub my_init {
  init_i2c();
  sleep 1;
  i2c_write($ktd2026_addr, $control, 0x07);
  i2c_write($ktd2026_addr, $control, 0x04);
  i2c_write($ktd2026_addr, $led_red, $led_on_drive);
  i2c_write($ktd2026_addr, $led_green, $led_on_drive);
  i2c_write($ktd2026_addr, $led_blue, $led_on_drive);
}

sub leds_on {
  my $val = ($led_on << $red_ctrl_bits) | ($led_on << $green_ctrl_bits) | ($led_on << $blue_ctrl_bits);
  i2c_write($ktd2026_addr, $led_enable, $val);
}

sub leds_off {
  my $val = ($led_off << $red_ctrl_bits) | ($led_off << $green_ctrl_bits) | ($led_off << $blue_ctrl_bits);
  i2c_write($ktd2026_addr, $led_enable, $val);
}

my_init();
leds_on();
sleep 1;
leds_off();
sleep 1;
leds_on();
sleep 1;
leds_off();
sleep 1;


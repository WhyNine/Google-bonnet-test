use strict;
use v5.28;

use lib "/home/pi";
use rt5645;
use rt5645_regs;
use misc;

my $SND_SOC_CLOCK_IN	=	0;
my $SND_SOC_CLOCK_OUT	=	1;

sub snd_rpi_aiy_voicebonnet_init {
	my $ret;
	rt5645_sel_asrc_clk_src(
		$RT5645_DA_STEREO_FILTER |
		$RT5645_AD_STEREO_FILTER |
		$RT5645_DA_MONO_L_FILTER |
		$RT5645_DA_MONO_R_FILTER,
		$RT5645_CLK_SEL_I2S1_ASRC);
	$ret = rt5645_set_dai_sysclk($RT5645_SCLK_S_MCLK);
	if ($ret < 0) {
		print("can't set sysclk: $ret\n");
		return $ret;
	}
	return 1;
}

sub snd_rpi_aiy_voicebonnet_hw_params {
	my $ret = 0;
	my $freq = $sample_rate * 256; #params_rate(params) * 512;

	#/* set codec PLL source to the 24.576MHz (MCLK) platform clock */
	$ret = rt5645_set_dai_pll($RT5645_PLL1_S_MCLK, $PLATFORM_CLOCK, $freq);
	if ($ret < 0) {
		print("can't set codec pll: $ret\n");
		return $ret;
	}
	$ret = rt5645_set_dai_sysclk($RT5645_SCLK_S_PLL1);
	return 0;
}

sub my_init {
  init_i2c();
  init_rt5645();
  snd_rpi_aiy_voicebonnet_init();
  snd_rpi_aiy_voicebonnet_hw_params();
}

my_init();

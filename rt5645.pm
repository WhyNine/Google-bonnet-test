package rt5645;

use v5.28;

our @EXPORT = qw ( rt5645_set_dai_sysclk rt5645_sel_asrc_clk_src $PLATFORM_CLOCK rt5645_set_dai_pll init_rt5645 $sample_rate );
use base qw(Exporter);

use strict;

use lib "/home/pi";
use rl6231;
use rt5645_regs;
use misc;

our $PLATFORM_CLOCK = 24576000;
our $sample_rate = 48000;
my $sample_bits = 16;
my $mic_vol = 0x7f;                  # +30dB, 2F = 0dB
my $boost_vol = 0x8;                 # 0=0dB, 8=52dB

my @init_list = (
	$RT5645_CHOP_DAC_ADC,	0x3600,
	$RT5645_CLSD_INT_REG1,	0xfd70,
	0x20,	0x611f,
	0x21,	0x4040,
	0x23,	0x0004
);

#**
# * rt5645_sel_asrc_clk_src - select ASRC clock source for a set of filters
# * @filter_mask: mask of filters.
# * @clk_src: clock source
# *
# * The ASRC function is for asynchronous MCLK and LRCK. Also, since RT5645 can
# * only support standard 32fs or 64fs i2s format, ASRC should be enabled to
# * support special i2s clock format such as Intel's 100fs(100 * sampling rate).
# * ASRC function will track i2s clock and generate a corresponding system clock
# * for codec. This function provides an API to select the clock source for a
# * set of filters specified by the mask. And the codec driver will turn on ASRC
# * for these filters if ASRC is selected as their clock source.
# */
sub rt5645_sel_asrc_clk_src {
  my ($filter_mask, $clk_src) = @_;
	my $asrc2_mask = 0;
	my $asrc2_value = 0;
	my $asrc3_mask = 0;
	my $asrc3_value = 0;

	return if index($clk_src, ($RT5645_CLK_SEL_SYS, $RT5645_CLK_SEL_I2S1_ASRC, $RT5645_CLK_SEL_I2S2_ASRC, $RT5645_CLK_SEL_SYS2)) < 0;

	if ($filter_mask & $RT5645_DA_STEREO_FILTER) {
		$asrc2_mask |= $RT5645_DA_STO_CLK_SEL_MASK;
		$asrc2_value = ($asrc2_value & ~$RT5645_DA_STO_CLK_SEL_MASK)
			| ($clk_src << $RT5645_DA_STO_CLK_SEL_SFT);
	}

	if ($filter_mask & $RT5645_DA_MONO_L_FILTER) {
		$asrc2_mask |= $RT5645_DA_MONOL_CLK_SEL_MASK;
		$asrc2_value = ($asrc2_value & ~$RT5645_DA_MONOL_CLK_SEL_MASK)
			| ($clk_src << $RT5645_DA_MONOL_CLK_SEL_SFT);
	}

	if ($filter_mask & $RT5645_DA_MONO_R_FILTER) {
		$asrc2_mask |= $RT5645_DA_MONOR_CLK_SEL_MASK;
		$asrc2_value = ($asrc2_value & ~$RT5645_DA_MONOR_CLK_SEL_MASK)
			| ($clk_src << $RT5645_DA_MONOR_CLK_SEL_SFT);
	}

	if ($filter_mask & $RT5645_AD_STEREO_FILTER) {
		$asrc2_mask |= $RT5645_AD_STO1_CLK_SEL_MASK;
		$asrc2_value = ($asrc2_value & ~$RT5645_AD_STO1_CLK_SEL_MASK)
			| ($clk_src << $RT5645_AD_STO1_CLK_SEL_SFT);
	}

	if ($filter_mask & $RT5645_AD_MONO_L_FILTER) {
		$asrc3_mask |= $RT5645_AD_MONOL_CLK_SEL_MASK;
		$asrc3_value = ($asrc3_value & ~$RT5645_AD_MONOL_CLK_SEL_MASK)
			| ($clk_src << $RT5645_AD_MONOL_CLK_SEL_SFT);
	}

	if ($filter_mask & $RT5645_AD_MONO_R_FILTER)  {
		$asrc3_mask |= $RT5645_AD_MONOR_CLK_SEL_MASK;
		$asrc3_value = ($asrc3_value & ~$RT5645_AD_MONOR_CLK_SEL_MASK)
			| ($clk_src << $RT5645_AD_MONOR_CLK_SEL_SFT);
	}

	if ($asrc2_mask) {
		snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_ASRC_2,
			$asrc2_mask, $asrc2_value);
  }
	if ($asrc3_mask) {
		snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_ASRC_3,
			$asrc3_mask, $asrc3_value);
  }
	return 0;
}

sub rt5645_set_dai_sysclk {
  my ($clk_id) = @_;
	my $reg_val = 0;
	if ($clk_id == $RT5645_SCLK_S_MCLK) {
		$reg_val |= $RT5645_SCLK_SRC_MCLK;
  }
	if ($clk_id == $RT5645_SCLK_S_PLL1) {
		$reg_val |= $RT5645_SCLK_SRC_PLL1;
  }
	if ($clk_id == $RT5645_SCLK_S_RCCLK) {
		$reg_val |= $RT5645_SCLK_SRC_RCCLK;
  }
	snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_GLB_CLK, $RT5645_SCLK_SRC_MASK, $reg_val);
	return 0;
}

sub rt5645_set_dai_pll {
  my ($source, $freq_in, $freq_out) = @_;
	my $pll_code = {};
	my $ret;

  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_GLB_CLK, $RT5645_PLL1_SRC_MASK, $RT5645_PLL1_SRC_MCLK);
	$ret = rl6231_pll_calc($freq_in, $freq_out, $pll_code);
	if ($ret < 0) {
		print("Unsupported input clock $freq_in\n");
		return $ret;
	}
  print("bypass=" . $pll_code->{'m_bp'} . " m=" . ($pll_code->{"m_bp"} ? 0 : $pll_code->{"m_code"}) . " n=" . $pll_code->{"n_code"} . " k=" . $pll_code->{"k_code"} . "\n");

	snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PLL_CTRL1, $pll_code->{"n_code"} << $RT5645_PLL_N_SFT | $pll_code->{"k_code"});
	snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PLL_CTRL2, 
    (($pll_code->{"m_bp"} ? 0 : $pll_code->{"m_code"}) << $RT5645_PLL_M_SFT) | ($pll_code->{"m_bp"} << $RT5645_PLL_M_BP_SFT));

	return 0;
}

sub write_private_register {
  my ($reg, $val) = @_;
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_INDEX, $reg);
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_DATA, $val);
}

sub update_private_register {
  my ($reg, $mask, $val) = @_;
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_PRIV_INDEX, $reg);
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PRIV_DATA, $mask, $val);
}

sub rt5645_i2c_probe {
	my ($ret, $i, $val);

	#/*
	# * Read after 400msec, as it is the interval required between
	# * read and power On.
	# */
	msleep(400);
	$val = snd_soc_component_read($RT5645_I2C_ADDR, $RT5645_VENDOR_ID2);
  if ( $val != $RT5645_DEVICE_ID) {
    printf("incorrect rt5645 device ID, val is %x\n", $val);
    return -1;
  }

	$val = snd_soc_component_read($RT5645_I2C_ADDR, $RT5645_VENDOR_ID1);
  if ( $val != 0x10ec) {
    printf("incorrect rt5645 vendor ID, val is %x\n", $val);
    return -1;
  }

	snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_RESET, 0);
  msleep(400);

	snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_AD_DA_MIXER, 0x8080);

  foreach $i (0 .. (scalar(@init_list) / 2) - 1) {
    write_private_register($init_list[$i * 2], $init_list[$i * 2 + 1]);
  }
	snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_ASRC_4, 0x0120);

	update_private_register($RT5645_CLSD_OUT_CTRL, 0xc0, 0xc0);

	snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_ADDA_CLK1,
		$RT5645_I2S_PD1_MASK, $RT5645_I2S_PD1_2);

	#timer_setup(&rt5645->btn_check_timer, rt5645_btn_check_callback, 0);

	snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_MICBIAS,
		$RT5645_PWR_CLK25M_MASK, $RT5645_PWR_CLK25M_PD);

	return 0;
}

sub rt5645_hw_params {
	my $val_len = -1;
  my ($val_clk, $mask_clk, $dl_sft, $pre_div, $bclk_ms, $frame_size, $bclk);

	$pre_div = rl6231_get_clk_info($PLATFORM_CLOCK, $sample_rate);
	if ($pre_div < 0) {
		print("Unsupported clock setting\n");
		return -1;
	}
	$frame_size = $sample_bits * 2;
  $dl_sft = 2;

	$bclk_ms = $frame_size > 32;
	$bclk = $sample_rate * (32 << $bclk_ms);
	print("bclk is $bclk Hz and lrck is $sample_rate Hz\n");

  $val_len = 0x0 if $sample_bits == 16;
  $val_len = 0x1 if $sample_bits == 20;
  $val_len = 0x2 if $sample_bits == 24;
  $val_len = 0x3 if $sample_bits == 8;
  return -1 if $val_len < 0;

  $mask_clk = $RT5645_I2S_PD1_MASK;
  $val_clk = $pre_div << $RT5645_I2S_PD1_SFT;
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_I2S1_SDP,
    (0x3 << $dl_sft), ($val_len << $dl_sft));
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_ADDA_CLK1, $mask_clk, $val_clk);

  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_DIG1, $RT5645_PWR_I2S1, $RT5645_PWR_I2S1);      # enable power to I2S1

	return 0;
}

sub rt5645_set_dai_fmt {
	my $reg_val = 0;
  my $pol_sft = 7;

  $reg_val |= $RT5645_I2S_MS_S;
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_I2S1_SDP,
    $RT5645_I2S_MS_MASK | (1 << $pol_sft) | $RT5645_I2S_DF_MASK, $reg_val);
	return 0;
}

# Not quite sure why I need this but it seems to enable the mic inputs - not used now
sub rt5645_jack_detect {
	my $val;

  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_CHARGE_PUMP, 0x0e06);               # ?????

  #/* Power up necessary bits for JD */
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_ANLG1, $RT5645_PWR_MB | $RT5645_PWR_VREF2, $RT5645_PWR_MB | $RT5645_PWR_VREF2);   # enable MBIAS and VREF2 power
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_MIXER, $RT5645_PWR_LDO2, $RT5645_PWR_LDO2);                       # enable LDO2 power
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_VOL, $RT5645_PWR_MIC_DET, $RT5645_PWR_MIC_DET);                   # enable MIC IN detect power

  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_JD_CTRL3, 0x00f0);                                                          # enable jack detection, high trigger
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_IN1_CTRL2, $RT5645_CBJ_MN_JD, $RT5645_CBJ_MN_JD);                     # set IN1 manual trigger to high to low
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_IN1_CTRL1, $RT5645_CBJ_BST1_EN, $RT5645_CBJ_BST1_EN);                 # enable IN1
  msleep(100);
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_IN1_CTRL2, $RT5645_CBJ_MN_JD, 0);                                     # set IN1 manual trigger to low to high

  msleep(600);
  $val = snd_soc_component_read($RT5645_I2C_ADDR, $RT5645_IN1_CTRL3);                                                           # read IN1 port final status
  $val &= 0x7;
  print("IN1 val = $val\n");

}

sub enable_mic {
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_CHARGE_PUMP, 0x0e06);               # ?????
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_ANLG1, $RT5645_PWR_MB | $RT5645_PWR_VREF2, $RT5645_PWR_MB | $RT5645_PWR_VREF2);   # enable MBIAS and VREF2 power  ?????
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_MIXER, $RT5645_PWR_LDO2, $RT5645_PWR_LDO2);                       # enable LDO2 power ??????????
  #the left and right analog ADC can be powered down separately by setting pow_adc_l (MX-61[2]) and pow_adc_r (MX-61[1]).
  my $pwr = $RT5645_PWR_I2S1 | $RT5645_PWR_ADC_L | $RT5645_PWR_ADC_R;                                               # turn on power to I2S interface and both ADCs
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_DIG1, $pwr, $pwr);
  $pwr = $RT5645_PWR_BST2_P | $RT5645_PWR_BST2 | $RT5645_PWR_BST1;                                                  # turn on power to Boost 1/2
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_ANLG2, $pwr, $pwr);
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_DIG2, $RT5645_PWR_ADC_S1F, $RT5645_PWR_ADC_S1F);      # turn on power to Stereo ADC diginal filter block (not convinced)
  #And the volume control of the stereo ADC is also separately controlled by ad_gain_l (MX-1C[14:8]) and ad_gain_r (MX-1C[6:0]).
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_STO1_ADC_DIG_VOL, ($mic_vol << $RT5645_ADC_L_VOL_SFT) | ($mic_vol << $RT5645_ADC_R_VOL_SFT));

  # mic path is IN1/2 -> Boost1/2 -> ADC L/R -> Stereo1_ADC_Mixer_L/R (aka IF_ADC1)
  # adjust MX0D[11:8] to boost IN2 mic volume, MX0A[15:12] for IN1 mic volume
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_IN1_CTRL1, $RT5645_CBJ_BST1_EN | ($boost_vol << $RT5645_CBJ_BST1_SFT), 
    $RT5645_CBJ_BST1_EN | $RT5645_CBJ_BST1_MASK);                                                               # enable IN1 and set Boost 1 vol
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_IN2_CTRL, $boost_vol << $RT5645_BST_SFT1);                  # set Boost 2 vol
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_REC_L2_MIXER, ~$RT5645_M_BST2_RM_L);                        # unmute only Boost1 to ADC and set gain to 0dB (in RECMIXL)
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_REC_R2_MIXER, ~$RT5645_M_BST2_RM_R);                        # unmute only Boost2 to ADC and set gain to 0dB (in RECMIXR)
  snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_STO1_ADC_MIXER, $RT5645_ADC_1_SRC_ADC | $RT5645_M_ADC_L2 | $RT5645_M_ADC_R2);   # select ADC output to go to Stereo1_ADC_Mixer
  # ??????
  snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_ANLG2, $RT5645_PWR_MB1, $RT5645_PWR_MB1);         # enable power for micbias1   (not sure whether it should be micbias2)
  #snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_ASRC_1, ????)                                              # I'm sure I should enqable ASRC for I2S1 but the defs don't align with the pdf!!??
}

sub enable_speaker {
    snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_SPK_L_MIXER, 
      ~$RT5645_M_DAC_L1_SM_L, $RT5645_M_DAC_L1_SM_L);                                                           # unmute DACL1 to speaker mixer
    snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_SPK_R_MIXER, 
      ~$RT5645_M_DAC_R1_SM_R, $RT5645_M_DAC_R1_SM_R);                                                           # unmute DACR1 to speaker mixer
    snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_STO_DAC_MIXER, 
      $RT5645_M_DAC_L2 | $RT5645_M_DAC_R2 | $RT5645_M_DAC_R1_STO_L | $RT5645_M_DAC_L1_STO_R);                   # Stereo DAC Digital Mixer Control
    snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_PWR_DIG1,
			$RT5645_PWR_CLS_D | $RT5645_PWR_CLS_D_R |	$RT5645_PWR_CLS_D_L | $RT5645_PWR_DAC_L1 | $RT5645_PWR_DAC_R1,
			$RT5645_PWR_CLS_D | $RT5645_PWR_CLS_D_R |	$RT5645_PWR_CLS_D_L | $RT5645_PWR_DAC_L1 | $RT5645_PWR_DAC_R1); # enable power for DACs and power amps
    snd_soc_component_write($RT5645_I2C_ADDR, $RT5645_SPK_VOL, 0);                                              # unmute speakers and set vol to 12dB
		snd_soc_component_update_bits($RT5645_I2C_ADDR, $RT5645_GEN_CTRL3,
			$RT5645_DET_CLK_MASK, $RT5645_DET_CLK_MODE1);
}

sub init_rt5645 {
  rt5645_i2c_probe();
  rt5645_set_dai_fmt();
  rt5645_hw_params();
  #enable_mic();
  enable_speaker();
}


1;

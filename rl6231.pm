package rl6231;

use v5.28;

our @EXPORT = qw ( rl6231_get_clk_info rl6231_pll_calc rl6231_get_clk_info );
use base qw(Exporter);


use strict;

use lib "/home/pi";
use misc;

my $RL6231_PLL_INP_MAX = 40000000;
my $RL6231_PLL_INP_MIN = 256000;
my $RL6231_PLL_N_MAX =	0x1ff;
my $RL6231_PLL_K_MAX =	0x1f;
my $RL6231_PLL_M_MAX =	0xf;

my @pll_preset_table = (
	{"pll_in" => 19200000,  "pll_out" => 4096000,  "k" => 23, "n" => 14, "m" => 1, "m_bp" => 0},
	{"pll_in" => 19200000,  "pll_out" => 24576000,  "k" => 3, "n" => 30, "m" => 3, "m_bp" => 0},
);


# all vars were int in C version, not sure whether this sub is correct
sub find_best_div {
  my ($in, $max, $div) = @_;
	my $d;
	return 1 if ($in <= $max);
	$d = int($in / $max);
	$d++ if ($in % $max);
	while ($div % $d != 0) {
		$d++;
  }
	return $d;
}

#/**
# * rl6231_pll_calc - Calcualte PLL M/N/K code.
# * @freq_in: external clock provided to codec.
# * @freq_out: target clock which codec works on.
# * @pll_code: Pointer to structure with M, N, K and bypass flag.
# *
# * Calcualte M/N/K code to configure PLL for codec.
# *
# * Returns 0 for success or negative error code.
# */
sub rl6231_pll_calc {
  my ($freq_in, $freq_out, $pll_code) = @_;
	my $max_n = $RL6231_PLL_N_MAX;
  my $max_m = $RL6231_PLL_M_MAX;
	my ($i, $k, $n_t);
	my ($k_t, $min_k, $max_k);
  my $n = 0;
  my $m = 0;
  my $m_t = 0;
	my ($red, $pll_out, $in_t, $out_t, $div, $div_t);
	my $red_t = abs($freq_out - $freq_in);
	my ($f_in, $f_out, $f_max);
	my $bypass = 0;

	if ($RL6231_PLL_INP_MAX < $freq_in || $RL6231_PLL_INP_MIN > $freq_in) {
    print("RL6231 PLL freq out of bounds\n");
    return -1;
  }

  {
    use integer;                                                                # force integer arithmetic from now on
    my $done = 0;
    foreach $i (0 .. $#pll_preset_table) {
      if ($freq_in == $pll_preset_table[$i]->{"pll_in"} &&
        $freq_out == $pll_preset_table[$i]->{"pll_out"}) {
        $k = $pll_preset_table[$i]->{"k"};
        $m = $pll_preset_table[$i]->{"m"};
        $n = $pll_preset_table[$i]->{"n"};
        $bypass = $pll_preset_table[$i]->{"m_bp"};
        $done = 1;
      }
    }

    if ($done == 0) {
      $min_k = 80000000 / $freq_out - 2;
      $max_k = 150000000 / $freq_out - 2;
      if ($max_k > $RL6231_PLL_K_MAX) {
        $max_k = $RL6231_PLL_K_MAX;
      }
      if ($min_k > $RL6231_PLL_K_MAX) {
        $min_k = $max_k = $RL6231_PLL_K_MAX;
      }
      $div_t = gcd($freq_in, $freq_out);
      $f_max = 0xffffffff / $RL6231_PLL_N_MAX;
      $div = find_best_div($freq_in, $f_max, $div_t);
      $f_in = $freq_in / $div;
      $f_out = $freq_out / $div;
      $k = $min_k;
      for (my $k_t = $min_k; $k_t <= $max_k; $k_t++) {
        for (my $n_t = 0; $n_t <= $max_n; $n_t++) {
          $in_t = $f_in * ($n_t + 2);
          $pll_out = $f_out * ($k_t + 2);
          if ($in_t == $pll_out) {
            $bypass = 1;
            $n = $n_t;
            $k = $k_t;
            goto code_find;
          }
          $out_t = $in_t / ($k_t + 2);
          $red = abs($f_out - $out_t);
          if ($red < $red_t) {
            $bypass = 1;
            $n = $n_t;
            $m = 0;
            $k = $k_t;
            if ($red == 0) {
              goto code_find;
            }
            $red_t = $red;
          }
          for (my $m_t = 0; $m_t <= $max_m; $m_t++) {
            $out_t = $in_t / (($m_t + 2) * ($k_t + 2));
            $red = abs($f_out - $out_t);
            if ($red < $red_t) {
              $bypass = 0;
              $n = $n_t;
              $m = $m_t;
              $k = $k_t;
              if ($red == 0) {
                goto code_find;
              }
              $red_t = $red;
            }
          }
        }
      }
      print("Only get approximation about PLL\n");
    }
  }
code_find:

	$pll_code->{"m_bp"} = $bypass;
	$pll_code->{"m_code"} = $m;
	$pll_code->{"n_code"} = $n;
	$pll_code->{"k_code"} = $k;
	return 0;
}

sub rl6231_get_clk_info {
  my ($sclk, $rate) = @_;
	my $i;
	my @pd = (1, 2, 3, 4, 6, 8, 12, 16);

	if (($sclk <= 0) || ($rate <= 0)) {
		return -1;
  }
	$rate = $rate << 8;
	foreach $i (0 .. scalar(@pd) - 1) {
		if ($sclk == $rate * $pd[$i]) {
			return $i;
    }
  }

	return -1;
}


1;

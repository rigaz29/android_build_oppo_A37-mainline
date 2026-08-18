#!/usr/bin/env bash
# Config untuk msm8916-mainline/linux-panel-drivers
# Taruh di config/oppo-a37.sh, dan DTB-nya di dtb/
#
# DTB: hasil kompilasi arch/arm/boot/dts/qcom/msm8916-mtp-15399.dts
# dari rigaz29/kernel_oppo_msm8939 @ 0.0
#   make ARCH=arm msm8916-mtp-15399.dtb
#
# -r power  -> nama supply di driver yang dihasilkan jadi "power-supply",
#              sesuai node panel@0 di msm8916-oppo-a37.dts

OPTIONS=(-r power)
PANELS=(
	[oppo15399boe_ili9881c_720p_video]="oppo,a37-boe-ili9881c"
	[oppo15399tm_nt35521s_720p_video]="oppo,a37-tm-nt35521s"
	[oppo15399truly_nt35521s_720p_video]="oppo,a37-truly-nt35521s"
)

makecert.exe -n "CN=%1" -r -pe -a sha512 -len 4096 -cy authority -sv CARoot.pvk CARoot.cer
pvk2pfx.exe -pvk CARoot.pvk -spc CARoot.cer -pfx CARoot.pfx -po GameNight!12
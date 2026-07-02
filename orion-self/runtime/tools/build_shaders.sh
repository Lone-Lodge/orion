#!/bin/sh
# Regenerate vs_dxbc.h / ps_dxbc.h from shader.hlsl (run from runtime/).
FXC="C:/Program Files (x86)/Windows Kits/10/bin/10.0.22621.0/x64/fxc.exe"
"$FXC" //nologo //T vs_5_0 //E vs //Fh vs_dxbc.h //Vn g_vs_dxbc tools/shader.hlsl
"$FXC" //nologo //T ps_5_0 //E ps //Fh ps_dxbc.h //Vn g_ps_dxbc tools/shader.hlsl

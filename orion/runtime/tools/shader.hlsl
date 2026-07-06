struct VSIn  { float2 pos : POSITION; float4 col : COLOR; };
struct VSOut { float4 pos : SV_POSITION; float4 col : COLOR; };
VSOut vs(VSIn i) { VSOut o; o.pos = float4(i.pos, 0, 1); o.col = i.col; return o; }
float4 ps(VSOut i) : SV_TARGET { return i.col; }

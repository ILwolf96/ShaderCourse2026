Shader "Custom/RainDropCamLens"
{
    Properties {
        _MainTex("Source (Rendered Scene)", 2D) = "white" {}
        _RainIntensity("Rain Intensity (0..1)", Range(0,1)) = 0.5
        _DistortionStrength("Distortion Strength", Range(0,2)) = 0.5
        _DropSize("Drop Size (scale)", Range(0.1, 3.0)) = 1.0
        _StaticDrops("Static Drops (1 = fixed droplet positions)", Range(0,1)) = 1
        _DarkenMin("Darken at max intensity (0..1)", Range(0,1)) = 0.75
    }

    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Overlay" }
        LOD 200

        Pass {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;

            float _RainIntensity;
            float _DistortionStrength;
            float _DropSize;
            float _StaticDrops;
            float _DarkenMin;

            #define S(a,b,t) smoothstep(a,b,t)

            // deterministic noise helpers
            float3 N13(float p) {
                float3 p3 = frac(float3(p,p,p) * float3(.1031,.11369,.13787));
                p3 += dot(p3, p3.yzx + 19.19);
                return frac(float3((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y, (p3.y + p3.z)*p3.x));
            }
            float Saw(float b, float t) { return S(0., b, t) * S(1., b, t); }

            // A compact drop generator (keeps droplet shapes)
            float2 DropLayer2(float2 uv, float time, float dropSize) {
                float2 UVs = uv;
                uv.y += time * 0.75;

                float2 a = float2(6.0 * dropSize, 1.0 * dropSize);
                float2 grid = a * 2.0;
                float2 id = floor(uv * grid);

                float colShift = frac(sin(id.x*17.3)*0.5+0.5);
                uv.y += colShift;

                id = floor(uv * grid);
                float3 n = N13(id.x*35.2 + id.y*2376.1);
                float2 st = frac(uv*grid) - float2(.5, 0);

                float x = n.x - .5;
                float y = UVs.y * 20.0;
                float wiggle = sin(y + sin(y));
                x += wiggle * (.5 - abs(x)) * (n.z - .5);
                x *= .7;
                float ti = frac(time + n.z);
                y = (Saw(.85, ti) - .5) * .9 + .5;
                float2 p = float2(x, y);

                float d = length((st - p) * a.yx);
                float mainDrop = S(.4, .0, d);

                float r = sqrt(S(1., y, st.y));
                float cd = abs(st.x - x);
                float trail = S(.23*r, .15*r*r, cd);
                float trailFront = S(-.02, .02, st.y - y);
                trail *= trailFront * r * r;

                y = UVs.y;
                float trail2 = S(.2*r, .0, cd);
                float droplets = max(0., (sin(y*(1. - y)*120.) - st.y)) * trail2 * trailFront * n.z;
                y = frac(y*10.) + (st.y - .5);
                float dd = length(st - float2(x, y));
                droplets = S(.3, 0., dd);

                float m = mainDrop + droplets * r * trailFront;
                return float2(m, trail);
            }

            // small static micro-drops for detail
            float StaticDrops(float2 uv, float time, float dropSize) {
                uv *= 40.0 * dropSize;
                float2 id = floor(uv);
                uv = frac(uv) - .5;
                float3 n = N13(id.x*107.45 + id.y*3543.654);
                float2 p = (n.xy - .5) * .7 * dropSize;
                float d = length(uv - p);
                float fade = Saw(.025, frac(time + n.z));
                float c = S(.3, 0., d) * frac(n.z*10.0) * fade;
                return c;
            }

            // Compose two layers
            float2 Drops(float2 uv, float time, float dropSize) {
                float s = StaticDrops(uv, time, dropSize) * 1.5;
                float2 m1 = DropLayer2(uv, time, dropSize) * 1.0;
                float2 m2 = DropLayer2(uv * 1.85, time, dropSize * 0.9) * 0.6;
                float c = s + m1.x + m2.x;
                c = S(.3, 1., c);
                return float2(c, max(m1.y * 1.0, m2.y * 0.6));
            }

            fixed4 frag(v2f_img i) : SV_Target {
                float2 screenUV = i.uv.xy;
                float2 uv = ((i.uv * _ScreenParams.xy) - 0.5 * _ScreenParams.xy) / _ScreenParams.y;
                float T = _Time.y;

                // Animation speed driven by RainIntensity; if static requested, freeze positions
                float intensity = saturate(_RainIntensity);
                float speedFactor = 0.25 + intensity * 1.5; // low->slow, high->faster
                float timeMotion = (_StaticDrops > 0.5) ? 0.0 : (T * speedFactor);

                // Drop shape generation (procedural)
                float2 drops = Drops(uv, timeMotion * 0.2, _DropSize);

                // normals from drop thickness
                float2 e = float2(.001, 0);
                float cx = Drops(uv + e, timeMotion * 0.2, _DropSize).x;
                float cy = Drops(uv + e.yx, timeMotion * 0.2, _DropSize).x;
                float2 nrm = float2(cx - drops.x, cy - drops.x);

                // LOD (fake blur) based on trail intensity
                float focus = lerp(6.0 - drops.y, 2.0, S(.1, .2, drops.x));
                float lod = focus * 1.0;

                // base distortion scales with RainIntensity
                float baseDist = _DistortionStrength * lerp(0.3, 1.6, intensity);

                float oscAmp = intensity * 0.25;             // amplitude scales with intensity
                float oscFreq = 0.5 + intensity * 2.5;       // frequency scales with intensity
                float timeOsc = 1.0 + oscAmp * sin(T * oscFreq);
                float effDistortion = baseDist * timeOsc;

                // refractive offset
                float2 perturb = nrm * (effDistortion * 0.25);
                float2 sampleUV = screenUV + perturb;

                float4 texCoord = float4(sampleUV.x, sampleUV.y, 0, lod);
                float3 col = tex2Dlod(_MainTex, texCoord).rgb;

                float darken = lerp(1.0, saturate(_DarkenMin), saturate(intensity * 0.9));
                col *= darken;

                return fixed4(col, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

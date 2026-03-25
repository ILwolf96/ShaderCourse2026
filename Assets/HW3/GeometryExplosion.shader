Shader "Custom/Stage1/GeometryExplosion"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _ExplosionStrength ("Explosion Strength", Float) = 1.0
        _Speed ("Speed", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.0
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float _ExplosionStrength;
                float _Speed;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
            };

            struct GeoOut
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS   : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            [maxvertexcount(3)]
            void geom(triangle Varyings IN[3], inout TriangleStream<GeoOut> triStream)
            {
                float3 p0 = IN[0].positionWS;
                float3 p1 = IN[1].positionWS;
                float3 p2 = IN[2].positionWS;

                float3 faceNormal = normalize(cross(p1 - p0, p2 - p0));
                float offset = _Time.y * _Speed * _ExplosionStrength;

                [unroll]
                for (int i = 0; i < 3; i++)
                {
                    GeoOut OUT;
                    float3 movedWS = IN[i].positionWS + faceNormal * offset;
                    OUT.positionCS = TransformWorldToHClip(movedWS);
                    OUT.normalWS = faceNormal;
                    triStream.Append(OUT);
                }

                triStream.RestartStrip();
            }

            half4 frag(GeoOut IN) : SV_Target
            {
                Light mainLight = GetMainLight();
                half3 N = normalize(IN.normalWS);
                half ndotl = saturate(dot(N, normalize(mainLight.direction)));
                half3 lighting = LightingLambert(mainLight.color, mainLight.direction, N);
                return half4(_Color.rgb * lighting, _Color.a);
            }
            ENDHLSL
        }
    }
}
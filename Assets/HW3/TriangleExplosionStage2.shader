Shader "Custom/Stage2/TriangleExplosionURP"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct TriangleData
            {
                float4 offsetLife;
                float4 velocityAge;
                float4 accelActive;
            };

            StructuredBuffer<TriangleData> _TriangleData;

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
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
            void geom(triangle Varyings IN[3], uint primID : SV_PrimitiveID, inout TriangleStream<GeoOut> triStream)
            {
                TriangleData data = _TriangleData[primID];

                if (data.accelActive.w < 0.5f)
                    return;

                float3 offset = data.offsetLife.xyz;

                float3 p0 = IN[0].positionWS + offset;
                float3 p1 = IN[1].positionWS + offset;
                float3 p2 = IN[2].positionWS + offset;

                float3 faceNormal = normalize(cross(p1 - p0, p2 - p0));

                GeoOut OUT;

                OUT.positionCS = TransformWorldToHClip(p0);
                OUT.normalWS = faceNormal;
                triStream.Append(OUT);

                OUT.positionCS = TransformWorldToHClip(p1);
                OUT.normalWS = faceNormal;
                triStream.Append(OUT);

                OUT.positionCS = TransformWorldToHClip(p2);
                OUT.normalWS = faceNormal;
                triStream.Append(OUT);

                triStream.RestartStrip();
            }

            half4 frag(GeoOut IN) : SV_Target
            {
                Light mainLight = GetMainLight();
                half3 N = normalize(IN.normalWS);
                half3 lighting = LightingLambert(mainLight.color, mainLight.direction, N);

                return half4(_Color.rgb * lighting, _Color.a);
            }

            ENDHLSL
        }
    }
}
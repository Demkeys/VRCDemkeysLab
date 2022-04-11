Shader "DemkeysLab/LightingSystem/LitShader02"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MainCol ("Main Color", Color) = (1,1,1,1)
        _EmissiveTex ("Emissive Textyre", 2D) = "white" {}
        _EmissiveCol ("Emissive Color", Color) = (1,1,1,1)
        _AmbientCol ("Ambient Color", Color) = (1,1,1,1)
        _AmbientIntensity ("Ambient Intensity", Range(0,10)) = 1
        _SpecularCol ("Specular Color", Color) = (1,1,1,1)
        _Shininess ("Shininess", Range(0,30)) = 10
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            // #include "DemkeysLabCG.cginc" 

            #define LIGHTINGDEBUG 0


            // Use to set array size in shader, because array size is not
            // know ahead of time. When running for loops, use lightCount
            // instead of MAXLIGHTCOUNT
            #define MAXLIGHTCOUNT 30

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 camObjPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float4 vertexWorldPos : TEXCOORD3;
                float3 specularV : TEXCOORD4;

            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _MainCol;
            sampler2D _EmissiveTex;
            fixed4 _EmissiveCol;
            fixed4 _SpecularCol;
            float _Shininess;

            // Light variables (Set from script)
            int lightCount;
            fixed lightEnabled[MAXLIGHTCOUNT];
            float4 lightPos[MAXLIGHTCOUNT]; // World space position
            float lightIntensity[MAXLIGHTCOUNT];
            float4 lightColor[MAXLIGHTCOUNT];
            
            // Ambient light variables
            float4 _AmbientCol; float _AmbientIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.camObjPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1)).xyz;
                o.worldNormal = normalize(mul(unity_ObjectToWorld, float4(v.normal,0)).xyz);
                o.vertexWorldPos = mul(unity_ObjectToWorld, v.vertex);
                o.specularV = normalize(_WorldSpaceCameraPos-o.vertexWorldPos);
                // o.specularV = normalize(
                //     _WorldSpaceCameraPos-mul(unity_ObjectToWorld,float4(0,0,0,1)).xyz);
                return o;
            }

            float3 diffuse(
                float lightIntensity, fixed4 lightColor, float3 L, float3 N, float3 d)
            {
                float3 kd = max(0,dot(L,N));
                kd *= lightColor.rgb;
                kd *= lightIntensity;
                kd *= (1/(d*d));

                return kd;
            }

            float3 specular(float lightIntensity, float3 L, float3 N, float3 R, float3 V, float3 d)
            {
                float3 ks = max(0,dot(-R,V));
                ks = pow(ks, _Shininess*100);
                ks *= lightIntensity;
                ks *= _SpecularCol.rgb;
                ks *= (1/(d*d));

                return ks;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = 0;
                fixed3 texCol = tex2D(_MainTex, i.uv).rgb * _MainCol.rgb;
                fixed4 emission = tex2D(_EmissiveTex, i.uv);
                emission.rgb *= _EmissiveCol.rgb;

                fixed3 ambientCol = _AmbientCol.rgb*_AmbientIntensity;
                float3 diffuseCol = 0;
                float3 specularCol = 0;

                #if LIGHTINGDEBUG == 0
                for(int j = 0; j < lightCount; j++)
                {
                    if(lightEnabled[j] == 0) continue;

                    float3 L = normalize(lightPos[j].xyz-i.vertexWorldPos);
                    float3 N = i.worldNormal; // Normalized in vert.
                    float3 R = normalize(reflect(L,N));
                    float d_falloff = distance(lightPos[j].xyz, i.vertexWorldPos);
                    diffuseCol += diffuse(lightIntensity[j], lightColor[j], L, N, d_falloff);
                    specularCol += specular(lightIntensity[j], L, N, R, i.specularV, d_falloff);
                }
                // This allows the lighting system to be used even when not in play mode,
                // but this uses 4 other lights, instead of the custom lights in the
                // scene. Use this for debugging purposes.
                #elif LIGHTINGDEBUG == 1
                float3 DebugLightPos = float3(-20,5,-20);
                float PosSpacing = 7;
                float DebugLightIntensity = 1;
                int TotalLightsSqrt = 5; // Sqrt of the total number of lights.

                for(int j = 0; j < TotalLightsSqrt; j++)
                {
                    for(int k = 0; k < TotalLightsSqrt; k++)
                    {
                        col.rgb += diffuse(
                            float3(DebugLightPos.x+(j*PosSpacing),DebugLightPos.y,DebugLightPos.z+(k*PosSpacing)), 
                            DebugLightIntensity, fixed4(1,1,1,1), i.worldNormal, i.vertexWorldPos
                        );
                        col.rgb += specular(
                            float3(DebugLightPos.x+(j*PosSpacing),DebugLightPos.y,DebugLightPos.z+(k*PosSpacing)), 
                            i.worldNormal, i.vertexWorldPos
                        );    
                    }
                }

                #endif

                // col.rgb = i.normal;
                // col.rgb = unity_WorldToObject;
                // col.rgb = 0;
                // specularCol = 0;
                col.rgb = (texCol*(ambientCol+diffuseCol))+specularCol+emission;
                // col.rgb = texCol*(ambientCol+diffuseCol+specularCol+emission);
                // col.rgb += emission;
                return col;
            }
            ENDCG
        }
    }
}

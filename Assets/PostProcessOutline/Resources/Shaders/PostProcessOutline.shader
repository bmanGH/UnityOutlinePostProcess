Shader "Hidden/Outline Post Process"
{

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			#define USE_CUSTOM_NORMALS_TEXTURE
			//#define DEBUG_DRAW

			/////////////////////////////////////////////////////////////////////////////////////////
			//                                 Parameters                                          //
			/////////////////////////////////////////////////////////////////////////////////////////

			TEXTURE2D_SAMPLER2D(_CameraNormalsTexture, sampler_CameraNormalsTexture);
			TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
			TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
			TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
			half4 _MainTex_TexelSize;

			float _PixelScale;
			float _DepthThreshold;
			float _NormalThreshold;
			float _DepthNormalThreshold;
			float _DepthNormalThresholdScale;
			half4 _EdgeColor;
			float4x4 _ClipToView;

			struct Varyings
			{
				float4 vertex : SV_POSITION;
				float2 texcoord : TEXCOORD0;
				float2 texcoordStereo : TEXCOORD1;
				float3 viewSpaceDir : TEXCOORD2;
#if STEREO_INSTANCING_ENABLED
				uint stereoTargetEyeIndex : SV_RenderTargetArrayIndex;
#endif
			};

			/////////////////////////////////////////////////////////////////////////////////////////
			//                                  Functions                                          //
			/////////////////////////////////////////////////////////////////////////////////////////
			
			float SampleDepth(float2 uv)
			{
				float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
				return d;
			}

			float3 SampleNormal(float2 uv)
			{
				float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
				return DecodeViewNormalStereo(cdn) * float3(1.0, 1.0, -1.0);
			}

			void SampleDepthNormal(float2 uv, out float depth, out float3 normal)
			{
				depth = SampleDepth(uv);
				normal = SampleNormal(UnityStereoTransformScreenSpaceTex(uv));
			}

			half4 AlphaBlend(half4 src, half4 dst)
			{
				half3 color = (src.rgb * src.a) + (dst.rgb * (1 - src.a));
				half alpha = src.a + dst.a * (1 - src.a);
				return half4(color, alpha);
			}

			/////////////////////////////////////////////////////////////////////////////////////////
			//                               Vertex & Fragment                                     //
			/////////////////////////////////////////////////////////////////////////////////////////

			Varyings Vert(AttributesDefault v)
			{
				Varyings o;

				o.vertex = float4(v.vertex.xy, 0.0, 1.0);

				o.texcoord = TransformTriangleVertexToUV(v.vertex.xy);
			#if UNITY_UV_STARTS_AT_TOP
				o.texcoord = o.texcoord * float2(1.0, -1.0) + float2(0.0, 1.0);
			#endif
				o.texcoordStereo = TransformStereoScreenSpaceTex(o.texcoord, 1.0);

				// Transform our point first from clip to view space,
				// taking the xyz to interpret it as a direction.
				o.viewSpaceDir = mul(_ClipToView, o.vertex).xyz;

				return o;
			}

			half4 Frag(Varyings i) : SV_Target
			{
			#ifdef DEBUG_DRAW
				#ifdef USE_CUSTOM_NORMALS_TEXTURE
				float4 debug_normal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, i.texcoord).rgba;
				float debug_depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord).r;
				if (i.texcoord.x < 0.5)
					return debug_normal;
				else
					return half4(debug_depth, debug_depth, debug_depth, 1);
				#else
				float debug_depth;
				float3 debug_normal;
				SampleDepthNormal(i.texcoord, debug_depth, debug_normal);
				if (i.texcoord.x < 0.5)
					return half4(debug_normal, 1);
				else
					return half4(debug_depth, debug_depth, debug_depth, 1);
				#endif
			#endif

				float halfScaleFloor = floor(_PixelScale * 0.5);
				float halfScaleCeil = ceil(_PixelScale * 0.5);

				// Sample the pixels in an X shape, roughly centered around i.texcoord.
				// As the _CameraDepthTexture and _ViewSpaceNormalsTexture default samplers
				// use point filtering, we use the above variables to ensure we offset
				// exactly one pixel at a time.
				float2 bottomLeftUV = i.texcoord - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
				float2 topRightUV = i.texcoord + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;  
				float2 bottomRightUV = i.texcoord + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
				float2 topLeftUV = i.texcoord + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);

				float3 normal0, normal1, normal2, normal3;
				float depth0, depth1, depth2, depth3;
			#ifdef USE_CUSTOM_NORMALS_TEXTURE
				normal0 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomLeftUV).rgb;
				normal1 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topRightUV).rgb;
				normal2 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, bottomRightUV).rgb;
				normal3 = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, topLeftUV).rgb;
				depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r;
				depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r;
				depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r;
				depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r;
			#else
				SampleDepthNormal(bottomLeftUV, depth0, normal0);
				SampleDepthNormal(topRightUV, depth1, normal1);
				SampleDepthNormal(bottomRightUV, depth2, normal2);
				SampleDepthNormal(topLeftUV, depth3, normal3);
			#endif
				depth0 = LinearEyeDepth(depth0);
				depth1 = LinearEyeDepth(depth1);
				depth2 = LinearEyeDepth(depth2);
				depth3 = LinearEyeDepth(depth3);

				float3 viewNormal = normal0 * 2.0 - 1.0; // Transform the view normal from the 0...1 range to the -1...1 range.
				float NdotV = 1.0 - dot(viewNormal, -i.viewSpaceDir);

				// Return a value in the 0...1 range depending on where NdotV lies 
				// between _DepthNormalThreshold and 1.
				float normalThreshold01 = saturate((NdotV - _DepthNormalThreshold) / (1.0 - _DepthNormalThreshold));
				// Scale the threshold, and add 1 so that it is in the range of 1..._NormalThresholdScale + 1.
				float normalThreshold = normalThreshold01 * _DepthNormalThresholdScale + 1.0;

				// Modulate the threshold by the existing depth value;
				// pixels further from the screen will require smaller differences
				// to draw an edge.
				float depthThreshold = _DepthThreshold * depth0 * normalThreshold;

				float depthFiniteDifference0 = depth1 - depth0;
				float depthFiniteDifference1 = depth3 - depth2;
				// edgeDepth is calculated using the Roberts cross operator.
				// The same operation is applied to the normal below.
				// https://en.wikipedia.org/wiki/Roberts_cross
				float edgeDepth = sqrt(depthFiniteDifference0 * depthFiniteDifference0 + depthFiniteDifference1 * depthFiniteDifference1) * 100.0;
				edgeDepth = edgeDepth > depthThreshold ? 1 : 0;

				float3 normalFiniteDifference0 = normal1 - normal0;
				float3 normalFiniteDifference1 = normal3 - normal2;
				// Dot the finite differences with themselves to transform the 
				// three-dimensional values to scalars.
				float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
				edgeNormal = edgeNormal > _NormalThreshold ? 1 : 0;

				// Combine the results of the depth and normal edge detection operations
				float edge = max(edgeDepth, edgeNormal);

				// Blend color and edge
				half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
				half4 edgeColor = half4(_EdgeColor.rgb, _EdgeColor.a * edge);
				return AlphaBlend(edgeColor, color);
			}
			ENDHLSL
		}
    }

}

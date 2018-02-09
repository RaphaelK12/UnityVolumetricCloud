Shader "Render/CloudShader"
{
	Properties
	{
		_MainTex ("CloudVolumeTexture", 3D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		//to make intensity in frag shader working
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"
			#include "Assets/Common.cginc"

			struct vIn
			{
				float4 position		: SV_POSITION;

			};

			struct v2f
			{
				float4 position	: SV_POSITION;
				float4 dir_ws	: TEXCOORD1;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float4x4 _ClipToWorld;
			
			v2f vert (vIn v)
			{
				v2f o = (v2f)0;
				o.position = UnityObjectToClipPos(v.position);

				float4 clip = float4(o.position.xy, 0.0, 1.0);
				o.worldDirection = mul(_ClipToWorld, clip) - _WorldSpaceCameraPos;

				return o;
			}
			
			float4 frag (v2f i) : SV_Target
			{

				//Graphics.Blit(source, destination, this._mat);
				//will render a full screnn quad for position (0,1) in  both x and y
				//so it is better to map this to (-1,1)
				float4 col = fixed4(0,0,0,1);
				//do ray matching here;
				if (i.position_vs.y > 0.99 )
					col.r = 1;
				else
					col.g=  1;

				col = i.position_ws.z>0.5?1:0;
				return col;
			}
			ENDCG
		}
	}
}

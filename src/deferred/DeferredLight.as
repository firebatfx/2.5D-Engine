package deferred
{
	import CG.CgBody;
	import CG.Camera;
	import CG.SubCgBody;
	
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Matrix3D;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.errors.MissingContextError;
	//import starling.extensions.utils.ShaderUtils;
	import starling.textures.Texture;
	import starling.utils.Color;
	import starling.utils.VertexData;
	
	public class DeferredLight extends DisplayObject
	{
		
		private static const POINT_LIGHT_PROGRAM:String	= 'PointLightProgram';
		
		private var mNumEdges:int = 8;
		private var excircleRadius:Number;
		
		// Geometry data
		
		private var vertexData:VertexData;
		private var vertexBuffer:VertexBuffer3D;
		private var indexData:Vector.<uint>;
		private var indexBuffer:IndexBuffer3D;
		
		// Helpers
		
		private static var sHelperMatrix:Matrix = new Matrix();
		private static var position:Point = new Point();
		private static var tmpBounds:Rectangle = new Rectangle();
		
		// Lightmap
		private var lightPosition:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		private var lightProperties:Vector.<Number> = new <Number>[4,2,256,12];//light properties [radius, strength, height, radius^2]
		private var lightColor:Vector.<Number> = new <Number>[1, 0.4, 0.6, 0]; //light color [r, g, b, alpha]
		private var constants:Vector.<Number> = new <Number>[0.5, 1.0, 2.0, 0.0];
		private var screenDimensions:Vector.<Number> = new <Number>[0, 0, 0, 0];
		private var attenuationConstants:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 0.0];
		
		//private var glowImage:Image;
		private var mGlowVisible:Boolean;
		
		public var mZ:Number=0;
		/**This class is basic point light.
		 * 
		 * @param: _radius: Radius of light in pixels
		 * @param: _strenght: Brightness of light
		 * @param: _height: Height of light above stage. This is accualy 3d z axis. Bigger this value means light is 
		 * 					farther from screen plane.
		 * @param: _color: Color of the light
		 * @param: _glowVisible: If true there will be image added to represent glow of the light
		 * */
		public function DeferredLight(_radius:Number=1024,_strength:Number=1,_color:uint=0x24f7ff,_attenuation:Number = 30,_glowVisible:Boolean=false)
		{
			super();
			
			this.radius = _radius;
			this.strength = _strength;
			this.color = _color;
			this.attenuation = _attenuation;
			mGlowVisible = _glowVisible;

			screenDimensions[2] = Camera.worldFarPlane;
			screenDimensions[3] = Camera.worldFarPlane;;
			
			
			//**************************************************************
			setupGlow();
			this.touchable = false;
			
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
		
			
		}
		private function setupGlow():void{
			//setup glow
			if(mGlowVisible){
				//TODO GLOW
			}
		}
	
		/*-----------------------------
		Event handlers
		-----------------------------*/
		
		private function onContextCreated(event:Event):void
		{
			// The old context was lost, so we create new buffers and shaders			
			createBuffers();
			registerPrograms();
		}
		/** @inheritDoc */
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if (resultRect == null) resultRect = new Rectangle();
			
			var transformationMatrix:Matrix = targetSpace == this ? 
				null : getTransformationMatrix(targetSpace, sHelperMatrix);
			
			return vertexData.getBounds(transformationMatrix, 0, -1, resultRect);
		}
		
		/** Renders light to lightmap.*/
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
			if(DeferredRenderer.DeferredPass != DeferredRenderer.LIGHT_MAP)
			{
				return;
			}
			
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			support.finishQuadBatch();
			
			// make this call to keep the statistics display in sync.
			support.raiseDrawCount();		
			
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			// Set constants
			
			screenDimensions[0] = Starling.current.stage.stageWidth;
			screenDimensions[1] = Starling.current.stage.stageHeight;
			
			position.setTo(0, 0);
			localToGlobal(position, position);
			
				
			lightPosition[0] = position.x;
			lightPosition[1] = position.y;
			
			if(parent is SubCgBody){
				lightPosition[2] = parent.y+(parent as SubCgBody).z//+(parent as SubCgBody).offsetZ)*Math.SQRT2)
			}else{
				lightPosition[2] = parent.y+(parent as CgBody).z;	
			}
			
			// todo: think of something prettier?
			var bounds:Rectangle = getBounds(null, tmpBounds);			
			var scaledRadius:Number = bounds.width / 2;
			
			lightProperties[0] = scaledRadius;
			lightProperties[2] = 1 / scaledRadius;
			lightProperties[3] = scaledRadius * scaledRadius;			
			
			
			// activate program (shader) and set the required attributes / constants (5)
			context.setProgram(Starling.current.getProgram(POINT_LIGHT_PROGRAM));
			context.setVertexBufferAt(0, vertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); 
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);            
			
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, constants, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, lightPosition, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, lightProperties, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, lightColor, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 4, attenuationConstants, 1);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, screenDimensions, 1);	
			
			// finally: draw the object! (6)
			context.drawTriangles(indexBuffer, 0, mNumEdges);
			
			// reset buffers (7)
			context.setVertexBufferAt(0, null);

		}
		private function registerPrograms():void
		{
			var target:Starling = Starling.current;
			
			if(target.hasProgram(POINT_LIGHT_PROGRAM))
			{
				return;
			}	
			var vertexProgramCode:String =
				"m44 vt0, va0, vc0    \n"+// 4x4 matrix transform to output space
				"mov op, vt0     \n"+
				"mov v0, vt0 ";
			
			
			//fc0 = constans [0.5, 1.0, 2.0, 0.0]
			//fc1 = light position x,y,z,0
			//fc2 =  light properties [scaledRadius,strength,1 / scaledRadius,scaledRadius * scaledRadius]
			//fc3 = light color
			//fc4 = atteunationConstans [atteunation or 0 if it's less, 1 / (atteunation + 1),1-(1 / (atteunation + 1))]
			//fc5 = screenDimensions [width, height, near plane, far plane]
				
			//tex1 = normal
			//tex0 = depth
			
			var fragmentProgramCode:String =
				
				// Unpack screen coords to [0, 1] by
				// multiplying by 0.5 and then adding 0.5						
				
				"mul ft0.xyxy, v0.xyxy, fc0.xxxx     \n" +
				"add ft0.xy, ft0.xy, fc0.xx     \n" +
				"sub ft0.y, fc0.y, ft0.y      \n" +
			
				//sample normal texture
				"tex ft1, ft0.xy, fs1 <2d, clamp, linear, mipnone> \n" + 	
				"sub ft1.x, fc0.y, ft1.x      \n" + // y-axis should increase downwards
				
				// Then unpack normals from [0, 1] to [-1, 1]
				// by multiplying by 2 and then subtracting 1
				"mul ft1.xyz, ft1.xyz, fc0.zzz                  \n"+
				"sub ft1.xyz, ft1.xyz, fc0.yyy                \n"+
				
				"nrm ft1.xyz, ft1.xyz 						\n"+
				
				//sample depth texture
				"tex ft2, ft0.xy,  fs0 <2d, clamp, linear, mipnone>  \n" + 	
				//"neg ft2.x, ft2.x     \n"+//invert depth map  
				//"add ft2.x, ft2.x, fc0.y      \n"+ //+1
				
				
				// Calculate pixel position in eye space
				
				"mul ft3.xyxy, ft0.xyxy, fc5.xyxy			\n" + 
				
				//"mov ft3.xyxy, ft0.xyxy							\n" +  
				"mov ft3.z, ft2.x							\n" +  //put depth map x to z caord
				"mul ft3.z, ft3.z, fc5.w			\n" + //scale to far plane 
				/*-----------------------
				Calculate coincidence 
				between light and surface 
				normal
				-----------------------*/
				
				// float3 lightDirection3D = lightPosition.xyz - pixelPosition.xyz;
				// z(light) = positive float, z(pixel) = 0
				"sub ft3.xyz, fc1.xyz, ft3.xyz			\n" +
				"mov ft3.w, fc0.w			\n" +
				
				// Save length(lightDirection2D) to ft20.x for later shadow calculations
				/*"pow ft20.x, ft3.x, fc0.z			\n" +
				"pow ft20.y, ft3.y, fc0.z			\n" +
				"add ft20.x, ft20.x, ft20.y			\n" +
				"sqt ft20.x, ft20.x			\n" +
				"div ft20.x, ft20.x, fc2.x			\n" +*/
			
				// float3 lightDirNorm = normalize(lightDirection3D);
				"nrm ft7.xyz, ft3.xyz			\n" +
			
				// float amount = max(dot(normal, lightDirNorm), 0);
				// Put it in ft5.x
				"dp3 ft5.x, ft1.xyz, ft7.xyz			\n" +
				"max ft5.x, ft5.x, fc0.w			\n" +	//clamp to min zero
				
				/*-----------------------
				Calculate attenuation
				-----------------------*/
				
				// Linear attenuation
				// http://blog.slindev.com/2011/01/10/natural-light-attenuation/
				// Put it in ft5.y	
				"mov ft3.z, fc0.w			\n" + // attenuation is calculated in 2D
				"dp3 ft5.y, ft3.xyz, ft3.xyz			\n" +
				"div ft5.y, ft5.y, fc2.w			\n" +
				"mul ft5.y, ft5.y, fc4.x			\n" +
				"add ft5.y, ft5.y, fc0.y			\n" +
				"rcp ft5.y, ft5.y			\n" +					
				"sub ft5.y, ft5.y, fc4.y			\n" +
				"div ft5.y, ft5.y, fc4.z			\n" +
				
				//next fallof
				//http://imdoingitwrong.wordpress.com/2011/01/31/light-attenuation/
				/*'div ft7.x, ft7.x,fc2.x            \n'+  //distance / radius
				'add ft7.x, ft7.x,fc0.y            \n'+ //add 1
				'pow ft7.x, ft7.x ,fc0.z         \n'+ //^2
				'div ft7.x, fc2.y,ft7.x            \n'+ // strenght / above
				'mul ft5.y, ft5.x, ft7.x                \n'+*/
				
				/*-----------------------
				Finalize
				-----------------------*/
				
				// Output.Color = lightColor * coneAttenuation * lightStrength
				"mul ft6.xyz, ft5.yyy, fc3.xyz			\n" +
				"mul ft6.xyz, ft6.xyz	, ft5.x			\n" +
			
				// + (coneAttenuation * specular * specularStrength)						
				//"mul ft7.x, ft5.y, ft5.z			\n" +
				//"mul ft7.x, ft7.x, ft0.w			\n" +
				"mov ft6.w, fc0.y			\n" +
				//"mul ft6.w, ft6.w, ft5.x			\n" +
				
				// light = (specular * lightColor + diffuseLight) * lightStrength
				//"mul ft2.xyz, ft6.www, fc3.xyz			\n" +
				//"add ft2.xyz, ft2.xyz, ft6.xyz			\n" +
				"mul ft6.xyz, ft6.xyz, fc2.yyy 			\n" +
				//"mov ft2.w, fc0.y			\n" +

				"mov oc, ft6";          
			
			target.registerProgramFromSource(POINT_LIGHT_PROGRAM, vertexProgramCode, fragmentProgramCode);
			
		}
		private function calculateRealRadius(radius:Number):void
		{			
			var edge:Number = (2 * radius) / (1 + Math.sqrt(2));
			excircleRadius = edge / 2 * (Math.sqrt( 4 + 2 * Math.sqrt(2) ));
		}
		
		private function setupVertices():void
		{
			var i:int;
			
			// Create vertices		
			vertexData = new VertexData(mNumEdges+1);
			
			for(i = 0; i < mNumEdges; ++i)
			{
				var edge:Point = Point.polar(excircleRadius, (i * 2 * Math.PI) / mNumEdges + 22.5 * Math.PI / 180);
				vertexData.setPosition(i, edge.x, edge.y);
			}
			
			// Center vertex
			vertexData.setPosition(mNumEdges, 0.0, 0.0);
			
			// Create indices that span up the triangles			
			indexData = new <uint>[];
			
			for(i = 0; i < mNumEdges; ++i)
			{
				indexData.push(mNumEdges, i, (i + 1) % mNumEdges);
			}		
		}
		
		private function createBuffers():void
		{
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			if (vertexBuffer) vertexBuffer.dispose();
			if (indexBuffer)  indexBuffer.dispose();
			
			vertexBuffer = context.createVertexBuffer(vertexData.numVertices, VertexData.ELEMENTS_PER_VERTEX);
			vertexBuffer.uploadFromVector(vertexData.rawData, 0, vertexData.numVertices);
			
			indexBuffer = context.createIndexBuffer(indexData.length);
			indexBuffer.uploadFromVector(indexData, 0, indexData.length);
		}
		/**Set strenght of light.*/
		public function set strength(value:Number):void{
			lightProperties[1] = value;
		}
		/**Get strenght of light.*/
		public function get strength():Number{
			return lightProperties[1];
		}
		/**Set color of light*/
		public function set color(value:uint):void{
			lightColor[0] = Color.getRed(value) /255;
			lightColor[1] = Color.getGreen(value)/255;
			lightColor[2] = Color.getBlue(value)/255;
		}
		/**Get color of light*/
		public function get color():uint{
			return Color.rgb(lightColor[0]*255,lightColor[1]*255,lightColor[2]*255);
		}
		/**Get radius of light. This same radius has glow image*/
		public function get radius():Number
		{ 
			return lightProperties[0];
		}
		/**Set radius of light. This same radius has glow image*/
		public function set radius(value:Number):void
		{
			lightProperties[0]  = value;
			lightProperties[3] = value*value;
			calculateRealRadius(value);
			
			// Setup vertex data and prepare shaders			
			setupVertices();
			createBuffers();
			registerPrograms();
		}
		public function get attenuation():Number
		{ 
			return attenuationConstants[0];
		}
		public function set attenuation(value:Number):void
		{
			attenuationConstants[0] = value <= 0 ? Number.MIN_VALUE : value;
			attenuationConstants[1] = 1 / (attenuationConstants[0] + 1);
			attenuationConstants[2] = 1 - attenuationConstants[1];
		}
		/** @inheritDoc */
		public override function dispose():void
		{
			
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			if (vertexBuffer) vertexBuffer.dispose();
			if (indexBuffer)  indexBuffer.dispose();
			
			super.dispose();
		}
	}
}
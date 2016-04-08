package deferred
{
	import starling.utils.AssetManager;
	
	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.events.ResizeEvent;
	import starling.textures.Texture;
	import starling.utils.VertexData;
	import utils.ShaderUtils;
	
	public class DeferredLightLayer extends DisplayObject
	{
		private static var PROGRAM_DIFFUSE:String = 'DiffuseLayer';
		private static var PROGRAM_LIGHT:String = 'LightLayer';
		
		// vertex data 
		private var mVertexData:VertexData;
		private var mVertexBuffer:VertexBuffer3D;
		
		// index data
		private var mIndexData:Vector.<uint>;
		private var mIndexBuffer:IndexBuffer3D;
		
		// helper objects (to avoid temporary objects)
		private static var sHelperMatrix:Matrix = new Matrix();
		private static var sRenderAlpha:Vector.<Number> = new <Number>[0.0, 0.0, 0.0, 1.0];
		private static var sConst:Vector.<Number> = new <Number>[0.25, 0.5, 0.75, 1.0];
		private static var sWiniete:Vector.<Number> = new <Number>[1.0, 0.0, 0.0, 1.0];
		
		private var mLightMapTexture:Texture;
		private var mDiffuseTexture:Texture;
		private var isLightLayerVisible:Boolean = true;
		
		private var mAssets:AssetManager;
		
		/**Class that will generate and render lights overlay above stage
		 * @param: _diffuseRT: Diffuse render target genrated by Deferred Renderer
		 * @param: _LightMapRT: _LightMapRT render target genrated by Deferred Renderer
		 * */
		
		public function DeferredLightLayer(_diffuseRT:Texture,_LightMapRT:Texture,_assets:AssetManager)
		{
			//super();
			mDiffuseTexture = _diffuseRT;
			mLightMapTexture = _LightMapRT;
			mAssets = _assets;
			
			// setup vertex data and prepare shaders
			setupVertices();
			createBuffers();
			registerPrograms();
			
			// handle lost context
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
		}
		/** Disposes all resources of the display object. */
		public override function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			if (mVertexBuffer) mVertexBuffer.dispose();
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			super.dispose();
		}
		private function onContextCreated(event:Event):void
		{
			// the old context was lost, so we create new buffers and shaders.
			createBuffers();
			registerPrograms();
		}
		/** Returns a rectangle that completely encloses the object as it appears in another 
		 * coordinate system. */
		public override function getBounds(targetSpace:DisplayObject, resultRect:Rectangle=null):Rectangle
		{
			if (resultRect == null) resultRect = new Rectangle();
			
			var transformationMatrix:Matrix = targetSpace == this ? 
				null : getTransformationMatrix(targetSpace, sHelperMatrix);
			
			return mVertexData.getBounds(transformationMatrix, 0, -1, resultRect);
		}
		
		/** Creates the required vertex- and index data and uploads it to the GPU. */ 
		private function setupVertices():void
		{
			var i:int;
			
			// create vertices
			
			mVertexData = new VertexData(4);
			mVertexData.setUniformColor(0xFFF000);
			
			mVertexData.setTexCoords(0, 0.0, 0.0);
			mVertexData.setTexCoords(1, 1.0, 0.0);
			mVertexData.setTexCoords(2, 0.0, 1.0);
			mVertexData.setTexCoords(3, 1.0, 1.0);
			
			mVertexData.setPosition(0, 0.0, 0.0);
			mVertexData.setPosition(1, Starling.current.stage.stageWidth, 0.0);
			mVertexData.setPosition(2, 0.0, Starling.current.stage.stageHeight);
			mVertexData.setPosition(3, Starling.current.stage.stageWidth,Starling.current.stage.stageHeight);			
			
			// create indices that span up the triangles
			
			mIndexData = new <uint>[0,1,2,2,1,3];
		}
		
		/** Creates new vertex- and index-buffers and uploads our vertex- and index-data to those
		 *  buffers. */ 
		private function createBuffers():void
		{
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			if (mVertexBuffer) mVertexBuffer.dispose();
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			mVertexBuffer = context.createVertexBuffer(mVertexData.numVertices, VertexData.ELEMENTS_PER_VERTEX);
			mVertexBuffer.uploadFromVector(mVertexData.rawData, 0, mVertexData.numVertices);
			
			mIndexBuffer = context.createIndexBuffer(mIndexData.length);
			mIndexBuffer.uploadFromVector(mIndexData, 0, mIndexData.length);
		}
		
		/** Renders the object with the help of a 'support' object and with the accumulated alpha
		 * of its parent object. */
		public override function render(support:RenderSupport, alpha:Number):void
		{
			
			if(mDiffuseTexture.base ==  null || mLightMapTexture.base == null){return};
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			support.finishQuadBatch();
			
			// make this call to keep the statistics display in sync.
			support.raiseDrawCount();
			
			var context:Context3D = Starling.context;
			if (context == null) throw new MissingContextError();
			
			// apply the current blendmode
			support.applyBlendMode(false);
			support.setRenderTarget(null,4);
			// activate program (shader) and set the required buffers / constants 
			support.pushMatrix(); //store current matrix
			support.loadIdentity(); //reset matrix
			
			context.setProgram(Starling.current.getProgram(isLightLayerVisible?PROGRAM_LIGHT:PROGRAM_DIFFUSE));
			context.setVertexBufferAt(0, mVertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_2); 
			context.setVertexBufferAt(1, mVertexBuffer, VertexData.TEXCOORD_OFFSET, Context3DVertexBufferFormat.FLOAT_2);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, sRenderAlpha);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, sConst);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, sWiniete);
			context.setTextureAt(0, mDiffuseTexture.base);
			context.setTextureAt(1, mLightMapTexture.base);
			context.setTextureAt(2, mAssets.getTexture("LUT_standard").base);
			context.setTextureAt(3, mAssets.getTexture("Winieta2").base);
			
			// finally: draw the object!
			context.drawTriangles(mIndexBuffer, 0, 2);
			
			support.popMatrix();
			// reset buffers
			context.setTextureAt(0, null);
			context.setTextureAt(1, null);
			context.setTextureAt(2, null);
			context.setTextureAt(3, null);
			//context.setTextureAt(3, null);
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
		}
		
		/** Creates vertex and fragment programs from assembly. */
		private static function registerPrograms():void
		{
			var target:Starling = Starling.current;
			if (!target.hasProgram(PROGRAM_DIFFUSE)){ // already registered
				
				var vertexProgramCode:String =
					ShaderUtils.joinProgramArray(
						[
							'm44 op, va0, vc0', // 4x4 matrix transform to output space
							'mov v0, va1'
						]
					);
				
				var fragmentProgramCode:String =
					ShaderUtils.joinProgramArray(
						[
							'tex ft1, v0, fs0 <2d, clamp, linear, mipnone>',
							'tex ft2, v0, fs1 <2d, clamp, linear, mipnone>',
							'tex ft3, v0, fs2 <2d, clamp, linear, mipnone>',
							'tex ft4, v0, fs3 <2d, clamp, linear, mipnone>',
							//'tex ft3, v0, fs3 <2d, clamp, linear, mipnone>',
							'mov oc, ft1'
							
						]
					);
				target.registerProgramFromSource(PROGRAM_DIFFUSE,vertexProgramCode,fragmentProgramCode);
				
			}
			if (!target.hasProgram(PROGRAM_LIGHT)){ // already registered
				
				var vertexProgramCode2:String =
					ShaderUtils.joinProgramArray(
						[
							'm44 op, va0, vc0', // 4x4 matrix transform to output space
							'mov v0, va1'
						]
					);
				
				var fragmentProgramCode2:String =
					ShaderUtils.joinProgramArray(
						[
							//light multiply
							'tex ft1, v0, fs0 <2d, clamp, linear, mipnone>',
							'tex ft2, v0, fs1 <2d, clamp, linear, mipnone>',
							'mul ft1, ft1,ft2',
							//add winieta
							//'tex ft2, v0, fs3 <2d, clamp, linear, mipnone>',
							//'mul ft1, ft1,ft2',
							//End light multiply
							
						
							
							//Apply Luts color corrections
							//Reds
							'mov ft2.x, ft1.x',
							'mov ft2.y, fc1.x',
							'tex ft3, ft2, fs2 <2d, clamp, linear , mipnone>',
							'mov ft4.x, ft3.x',
							
							//Greens
							'mov ft2.x, ft1.y',
							'mov ft2.y, fc1.y',//second row
							'tex ft3, ft2, fs2 <2d, clamp, linear , mipnone>',
							'mov ft4.y, ft3.y',
							
							//Blues
							'mov ft2.x, ft1.z',
							'mov ft2.y, fc1.z', //third row
							'tex ft3, ft2, fs2 <2d, clamp, linear , mipnone>',
							'mov ft4.z, ft3.z',
							
							'mov ft4.w, fc1.w',
							
							//add Winiete
							'tex ft5, v0, fs3 <2d, clamp, linear, mipnone>',
							'mul ft5.xyz, ft5.xyz,fc2.xxx', //mull by winiete strenght
							//'div ft5.xyz, ft5.xyz,ft5.www', //pma
							//'mul ft4.xyz, ft4.xyz,ft5.xyz', //mul to color
							'mul ft4.xyz, ft4.xyz,ft5.xyz', //mul to color
							
							'mov oc ,ft4'
							//End apply Luts color corrections
							
							

						]
					);
				target.registerProgramFromSource(PROGRAM_LIGHT,vertexProgramCode2,fragmentProgramCode2);
			}
		}
		/**Debug function to turn on/off Light;
		 * */
		public function switchLightDisplay():void{
			isLightLayerVisible?isLightLayerVisible=false:isLightLayerVisible=true;
		}
	}
}
package deferred
{
	
	import CG.Camera;
	import CG.CgBody;

	import com.adobe.utils.AGALMiniAssembler;
	
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.BlendMode;
	import starling.display.DisplayObject;
	import starling.display.DisplayObjectContainer;
	import starling.display.Sprite;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.filters.FragmentFilter;
	import starling.textures.Texture;
	import starling.utils.Color;
	
	public class DeferredRenderer
	{
		public static const MRT:int = 1;
		public static const LIGHT_MAP:int = 2;
		public static const TRANSLUCENTS:int = 3;
		public static const AMBIENT_COLOR:uint = 0x4050DF;
		
		public static var DeferredPass:int = 0;
		public static var isDebugShown:Boolean=false;
		
		private static const AMBIENT_PROGRAM:String = 'AmbientProgram';
		private static const AMBIENT_LIGHT_PROGRAM:String = 'AmbientLightProgram';
		
		private var MRTPassRenderTargets:Vector.<Texture>;
		private var LIGHTPassRenderTargets:Vector.<Texture>;
		private var mDiffuseRT:Texture;
		private var mNormalsRT:Texture;
		private var mDepthRT:Texture;
		private var mLightMapRT:Texture;
		private var mBackGroundRT:Texture;
		
		private var isPrepared:Boolean = false;
		private var mAmbientColor:Vector.<Number> = new Vector.<Number>();
		private var mAmbientNormal:Vector.<Number> = new Vector.<Number>();
		private var mAmbientLightMap:Vector.<Number> = new Vector.<Number>();
		private var mCameraOffset:Vector.<Number> = new <Number>[0,0,0,0];
		private var mSupport:RenderSupport;
		private var prevRenderTargets:Vector.<Texture> = new Vector.<Texture>();
		private var mDepugSprite:Sprite;
		private var mWorldBoundSprite:Sprite;
		
		// debug
		private var mDebugActive:Boolean;
		private var mDebugNormal:DebugImage;
		private var mDebugDepth:DebugImage;
		private var mDebugLightMap:DebugImage;
		private var mDebugDiffuse:DebugImage;
		
		public var debugDeferredBodiesCount:int=0;
		public var debugDeferredLightsCount:int = 0;

		
		//vertex data
		protected var overlayVertexBuffer:VertexBuffer3D;
		protected var overlayIndexBuffer:IndexBuffer3D;
		protected var vertices:Vector.<Number> = new <Number>[-1, 1, 0, 0, 0, -1, -1, 0, 0, 1, 1,  1, 0, 1, 0, 1, -1, 0, 1, 1];
		protected var indices:Vector.<uint> = new <uint>[0,1,2,2,1,3];
		
		private var obs:Vector.<DisplayObject> = new Vector.<DisplayObject>();
		private var translucents:Vector.<DeferredImage> = new Vector.<DeferredImage>();
		private var opaques:Vector.<DeferredImage> = new Vector.<DeferredImage>();
		private var mGetheringSprite:Sprite;
		
		/**DeferredRenderer. Main class that is responsible for gathering all deffered images (deffered Movie Clips) and rendering them instead 
		 * of normal starling rendering.
		 * @param: _getheringSprite: Root container for all deferred images. Images out of this container won't be rendered via DeferredRenderer;
		 * @param: _worldBoundSprite: Sprite that will hold whole world. Only for caordinates calculation reson. Usually it will be the same sprite as _getheringSprite;
		 * @param: _debugSprite: Sprite where debug will be displayed.
		 * @param: _debugActive: Indicates if debug mode is active;*/
		
		
		public function DeferredRenderer(_getheringSprite:Sprite,_worldBoundSprite:Sprite,_debugSprite:Sprite=null,_debugActive:Boolean=true)
		{
			
			mGetheringSprite = _getheringSprite;
			mWorldBoundSprite = _worldBoundSprite;
			mDepugSprite = _debugSprite;
			mDebugActive = _debugActive;	
			
			
			prepare();
			registerPrograms();
			Starling.current.enableErrorChecking = true;
			// Handle lost context			
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			
			if(mDebugActive){
				mDebugNormal = new DebugImage(mNormalsRT,Starling.current.stage.stageWidth/2,Starling.current.stage.stageHeight/2);
				mDebugDepth = new DebugImage(mDepthRT,Starling.current.stage.stageWidth/2,Starling.current.stage.stageHeight/2);
				mDebugDepth.showChannel = 0;
				mDebugDepth.y = Starling.current.stage.stageHeight/2;
				
				mDebugLightMap = new DebugImage(mLightMapRT,Starling.current.stage.stageWidth/2,Starling.current.stage.stageHeight/2);
				mDebugLightMap.x = Starling.current.stage.stageWidth/2;
				
				mDebugDiffuse = new DebugImage(mDiffuseRT,Starling.current.stage.stageWidth/2,Starling.current.stage.stageHeight/2);
				mDebugDiffuse.x = Starling.current.stage.stageWidth/2;
				mDebugDiffuse.y = Starling.current.stage.stageHeight/2;
				
				if(mDepugSprite){
					mDepugSprite.addChild(mDebugNormal);
					mDepugSprite.addChild(mDebugDepth);
					mDepugSprite.addChild(mDebugLightMap);
					mDepugSprite.addChild(mDebugDiffuse);
				}
				switchDebugDisplay(false);
			}
		}
		private function prepare(scale:Number=-1, format:String="rgbaHalfFloat", repeat:Boolean=false):void
		{
			var context:Context3D = Starling.context;
			var w:Number = Starling.current.nativeStage.stageWidth;
			var h:Number = Starling.current.nativeStage.stageHeight;			
			// Create a quad for rendering full screen passes
			
			overlayVertexBuffer = context.createVertexBuffer(4, 5);
			overlayVertexBuffer.uploadFromVector(vertices, 0, 4);
			overlayIndexBuffer = context.createIndexBuffer(6);
			overlayIndexBuffer.uploadFromVector(indices, 0, 6);
			
			// Create render targets 
			// HALF_FLOAT format is used to increase the precision of specular params
			// No difference for normals or depth because those aren`t calculated at the run time but all RTs must be same format
			
			mDiffuseRT = Texture.empty(w, h, true, false, true, scale, format);
			mNormalsRT = Texture.empty(w, h, true, false, true, scale, format);
			mDepthRT = Texture.empty(w, h, true, false, true, scale, format);
			mLightMapRT = Texture.empty(w, h, true, false, true, scale, "bgra");
			mBackGroundRT = Texture.empty(w, h, true, false, true, scale,"bgra");
			
			
			MRTPassRenderTargets = new Vector.<Texture>();
			MRTPassRenderTargets.push(mDiffuseRT, mNormalsRT, mDepthRT);
			
			LIGHTPassRenderTargets = new Vector.<Texture>();
			LIGHTPassRenderTargets.push(mLightMapRT,null,null);
			
			//Ambients Color
			mAmbientColor[0] = -1;//R
			mAmbientColor[1] = 0;//G
			mAmbientColor[2] = 0;//B
			mAmbientColor[3] = 1;//A
			
			mAmbientNormal[0] = 0.5;//R
			mAmbientNormal[1] = 0.05;
			mAmbientNormal[2] = 0.75;//B
			mAmbientNormal[3] = 1;//A
			
			
			isPrepared = true;
		}
		
		private function registerPrograms():void
		{
			var target:Starling = Starling.current;
			if(!target.hasProgram(AMBIENT_PROGRAM))
			{
				
				var vertexProgramCode:String = 
					"mov op, va0 \n" + 
					"mov v0, va1     \n";  
				
				var fragmentProgramCode:String =
					
					"tex  fo0,  v0, fs0 <2d, clamp, linear, mipnone> \n"+  // sample background texture and write to diffuseRT 0
					
					"mov fo1, fc1      \n"+//write do normalRT
					
					//Gradient start
					"mul ft1.x, v0.y,fc2.w      \n"+
					"add ft1.x, ft1.x,fc2.y      \n"+
					"mov ft1.w, fc1.w      \n"+  //move 1 to w
					"mov ft1.yz, fc0.yz      \n"+ //move 0 to unused yz
					//Gradient stop
					
					"mov fo2, ft1      \n"; //write do depthRT
				
				
				
				target.registerProgramFromSource(AMBIENT_PROGRAM,vertexProgramCode,fragmentProgramCode);
			}
			
			if(!target.hasProgram(AMBIENT_LIGHT_PROGRAM))
			{
				var vertexLightProgramCode:String = 
					"mov op, va0 \n" +
					"mov v0, va1     \n"; 
				
				var fragmentLightProgramCode:String =
					
					"tex  ft0,  v0, fs0 <2d, clamp, linear, mipnone> \n"+  // sample texture 0 (depth) 
					"mov ft1, fc0      \n"+ //put ambient color
					
					"add ft1.xyz, ft1.xyz,ft0.yyy      \n"+ //add emissive
					
					"mov oc, ft1      \n"; //write do LightMapRT
				
				target.registerProgramFromSource(AMBIENT_LIGHT_PROGRAM,vertexLightProgramCode,fragmentLightProgramCode);
			}
		}
		/**Render form near camera, to far camera plane*/
		public function sortOnY(a:DisplayObject, b:DisplayObject):Number { //z depth sorting
			if(a.y > b.y){
				return -1;
			}
			else if(a.y < b.y){
				return 1;
			}else if(a.y == b.y){
				if(a.x <=b.x){
					return 1;
				}else{
					return -1;
				}
			}else{
				return 0;
			}
			
		}
		/**Rendering all opaques deffered images*/
		private function renderAllOpaques():void{
			
			function sortOnProgramName(a:DeferredImage, b:DeferredImage):Number {  //sort list based on a program
				if(a.programName < b.programName){
					return -1;
				}else if(a.programName > b.programName){
					return 1;
				}else{
					return sortOnY(a.parent,b.parent);
				}
			}
			opaques.sort(sortOnProgramName);
			for(var i:int=0;i<opaques.length;i++){
				draw(opaques[i]);
			}
		}
		private function renderAllTranslucents():void{
			for(var i:int=0;i<translucents.length;i++){
				draw(translucents[i]);
			}
		}
		/**Render all deferred bodies starting on:
		 * @param: _object:Root object of display object that we want to get all children recursively*/
		private function gatherAllDeferredBodies(_object:DisplayObject):void{
			
			if(_object is DisplayObjectContainer){
				for(var i:int=0;i<(_object as DisplayObjectContainer).numChildren;i++){
					gatherAllDeferredBodies((_object as DisplayObjectContainer).getChildAt(i)); //fallow tree by recurrence
				}
				
				
			}else if(_object is DeferredImage || _object is DeferredMovieClip){
				
				debugDeferredBodiesCount ++;
				
				//if object is translucent put it on translucent list 
				//and render it later in different pass
				if((_object as DeferredImage).translucent){ 
					if(_object.hasVisibleArea){
						translucents.push((_object as DeferredImage));
					}
					
				}else{ //if object is opaque
					if(_object.hasVisibleArea){
						opaques.push((_object as DeferredImage));
					}
					
				}
			}
			
		}
		/**Render all lights starting on:
		 * @param: _object:Root object of display object that we want to get all children recursively*/
		private function renderAllLights(_object:DisplayObject):void{
			
			if(_object is DisplayObjectContainer){
				for(var i:int=0;i<(_object as DisplayObjectContainer).numChildren;i++){
					renderAllLights((_object as DisplayObjectContainer).getChildAt(i)); //fallow tree by recurrence
				}
				
				
			}else if(_object is DeferredLight){
				debugDeferredLightsCount ++;
				draw(_object);
			}
			
		}
		public function render(support:RenderSupport):void{
			
			var context:Context3D = Starling.context; // (3)
			if (context == null) throw new MissingContextError()
			
			if(!isPrepared)
			{
				prepare();
			}	
			mSupport = support;
			
			prevRenderTargets.length = 0;
			prevRenderTargets.push(null, null, null);
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			mSupport.finishQuadBatch(); // (1)
			
			// make this call to keep the statistics display in sync.
			mSupport.raiseDrawCount(); // (2)
			
			mSupport.pushMatrix();
			mSupport.applyBlendMode(false);
			
			//******************************
			//Camera position
			mCameraOffset[0] = mWorldBoundSprite.x;
			mCameraOffset[1] = (1/mWorldBoundSprite.scaleX)*-1*mWorldBoundSprite.y/Camera.worldFarPlane;
			mCameraOffset[2] = Starling.current.stage.stageWidth;
			mCameraOffset[3] = (1/mWorldBoundSprite.scaleX)*Starling.current.stage.stageHeight/Camera.worldFarPlane;
			//******************************
			
			DeferredPass = MRT;
			mSupport.setRenderTargets(MRTPassRenderTargets);
			mSupport.clear();
			
			context.setTextureAt(0, mBackGroundRT.base);
			context.setVertexBufferAt(0, overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context.setProgram(Starling.current.getProgram(AMBIENT_PROGRAM));
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mAmbientColor);	
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, mAmbientNormal);	
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, mCameraOffset);	
			
			context.drawTriangles(overlayIndexBuffer); //draw full screen quad as background
			
			
			context.setTextureAt(0, null);
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			
			context.setDepthTest(true,Context3DCompareMode.LESS_EQUAL); //z depth test
			
			debugDeferredBodiesCount = 0;
			translucents.length = 0;
			opaques.length = 0;
			
			gatherAllDeferredBodies(mGetheringSprite);
			
			renderAllOpaques();
			
			//******************************
			DeferredPass = TRANSLUCENTS;
			Starling.context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE); //addative blend
			context.setDepthTest(false,Context3DCompareMode.LESS_EQUAL); //z depth test

			renderAllTranslucents();
			
			RenderSupport.setDefaultBlendFactors(false);
			
			context.setDepthTest(false,Context3DCompareMode.ALWAYS);
			//******************************
			DeferredPass = LIGHT_MAP;
			mAmbientLightMap[0] = Color.getRed(AMBIENT_COLOR) /255;
			mAmbientLightMap[1] = Color.getGreen(AMBIENT_COLOR)/255;
			mAmbientLightMap[2]  = Color.getBlue(AMBIENT_COLOR)/255;
			mAmbientLightMap[3] = 1;//A
			
			
			mSupport.setRenderTargets(LIGHTPassRenderTargets);
			mSupport.clear();
			
			context.setVertexBufferAt(0, overlayVertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context.setVertexBufferAt(1, overlayVertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context.setProgram(Starling.current.getProgram(AMBIENT_LIGHT_PROGRAM));
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mAmbientLightMap);	
			
			context.setTextureAt(0, mDepthRT.base);
			
			context.drawTriangles(overlayIndexBuffer);
			
			context.setVertexBufferAt(0, null);
			context.setVertexBufferAt(1, null);
			
			
			context.setTextureAt(1, mNormalsRT.base);
			context.setBlendFactors(Context3DBlendFactor.ONE,Context3DBlendFactor.ONE);
			
			debugDeferredLightsCount = 0;
			renderAllLights(mGetheringSprite);
			
			mSupport.applyBlendMode(false);
			context.setTextureAt(0, null);
			context.setTextureAt(1, null);
			//****************************** CLEANING
			DeferredPass = 0;
			mSupport.popMatrix();
			
			
			mSupport.setRenderTargets(prevRenderTargets); //restore RT
			
		}
		private function draw(object:DisplayObject, matrix:Matrix=null, alpha:Number=1.0,
							  antiAliasing:int=0):void
		{
			
			if (object == null) return;
			
			mSupport.loadIdentity();
			
			obs.length = 0;			
			
			//Collect all objects down to the stage, then sum up their transformations bottom up
			//Get transformation matrix
			while(object != Starling.current.stage)
			{
				obs.push(object);
				object = object.parent;
				
			}		
			
			for(var j:int = obs.length - 1; j >= 0; j--)
			{
				object = obs[j];
				mSupport.transformMatrix(object);
			}
			
			object.render(mSupport, alpha);
			
			
		}
		public function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			mSupport.dispose();
			mDiffuseRT.dispose();
			mNormalsRT.dispose();
			mDepthRT.dispose();
			mLightMapRT.dispose();
			mBackGroundRT.dispose();
			
			
			overlayVertexBuffer.dispose();
			overlayIndexBuffer.dispose();
			
			super.dispose();
		}
		private function onContextCreated(event:Event):void
		{
			isPrepared = false;
			prepare();
			registerPrograms();
		}
		/**Debug function to display generated normal map
		 * */
		public function switchDebugDisplay(_type:Boolean):void{
			if(mDebugActive && mDepugSprite){
				if(_type){
					
					mDepugSprite.addChild(mDebugNormal);
					mDepugSprite.addChild(mDebugDepth);
					mDepugSprite.addChild(mDebugLightMap);
					mDepugSprite.addChild(mDebugDiffuse);
					
					isDebugShown = true;
				}else{
					mDebugNormal.removeFromParent();
					mDebugDepth.removeFromParent();
					mDebugLightMap.removeFromParent();
					mDebugDiffuse.removeFromParent();
					
					isDebugShown = false;
				}
			}
			
		}
		public function get diffuseRT():Texture{return mDiffuseRT;}
		public function get normalRT():Texture{return mNormalsRT;}
		public function get depthRT():Texture{return mDepthRT;}
		public function get lightMapRT():Texture{return mLightMapRT;}
		public function get backGroundRT():Texture{return mBackGroundRT;}
	}
}
package deferred
{
	import CG.Camera;
	import CG.CgBody;
	
	import flash.display.Bitmap;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.filters.FragmentFilter;
	import starling.textures.SubTexture;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	import starling.utils.Color;
	import starling.utils.MatrixUtil;
	import starling.utils.VertexData;
	
	public class DeferredImage extends Image
	{
		public var programName:String="";
		
		private var mDeffTexture:DeferredTexture;
		private var _vertexData:VertexData = new VertexData(4);
		// member variables:
		private var mVertexBuffer:VertexBuffer3D;
		private var mIndexBuffer:IndexBuffer3D;
		private var mIndexData:Vector.<uint> = new <uint>[0,1,2,2,1,3];
		
		private var mConstants:Vector.<Number> = new <Number>[0,1,0.5,0];
		private var mConstants2:Vector.<Number> = new <Number>[0.1,0.18,0.7,0.9];
		private var mNormalConstant:Vector.<Number> = new <Number>[0.5,0.7,1,1];
		private var mCaordinates:Vector.<Number> = new <Number>[0,0,0,0];
		private var mUvOffsets:Vector.<Number> = new <Number>[0,0,0,0];
		private var mProperties:Vector.<Number> = new <Number>[0,1,0.5,0];
		private var mUVStartStop:Vector.<Number> = new <Number>[0,0,0,0];
		private var mOffsets:Vector.<Number> = new <Number>[1, 2,-1, -2];
		private var mWind:Vector.<Number> = new <Number>[0,3,0.3,3.5];
		private var mColor:Vector.<Number> = new <Number>[0,0,0,0];

		private var mDepth:Number;
		private var mEmissive:Number;
	
		private var mTranslucent:Boolean=false;
		private var mSelectedFilter:DeferredSelectionFilter;
		private var mWindFilter:LocalWindForce;
		private var mSyncRequired:Boolean = false;
		
		//Temp Objects
		private var tempPoint:Point = new Point(0,0);
		private var tempCgBody:CgBody;
		private var tempProgramName:int;
		
		//Programs
		private var fragmentShader:String;
		private var vertexShader:String;

		
		/**DeferredImage class is main class that will render all defereed objects
		 * It uses MRT.
		 * 
		 * @param: _defferedTexture: Defered texture class that contains diffuse, normal and depth map.
		 * 							Depth red channel is acctual depth and green channel is emissive.
		 * 							All texutres has to be on the same atlas.
		 * 
		 * @param: 			_depth: Scale depth. Initially all objects has depth 0-1 in local caordinates (Far point is 0 and near is 1);
		 * 							_depth scalar is a number that will scale local depth of object to World caordinate system.
		 * 							1 depth means that object is one tile in z demension.
		 * 
		 * @param: 			_emmissive: This property determines if object will be affected by light. Emissive 1 means that object will not be 
		 * 								affected by any light. It's also scales with depth green channel witch is responsible for emissive texture.
		 * 
		 * @pram:			_translucent: If true, object will be rendered in separate pass. All object that are not fully opaque must be rendered this way.
		 * 									Translucent object will not affect depth map (only emissive channel) or normal map.
		 * 									Translucent will be rendered in addative mode. Translucent will not be affected by lights.
		 * 								
		 * */
		public function DeferredImage(_defferedTexture:DeferredTexture,_depth:Number = 1,_emmissive:Number=0,_translucent:Boolean=false)
		{
			super(_defferedTexture);
			mDepth = Camera.calculateDepth(_depth);
			mEmissive = _emmissive;
			mTranslucent = _translucent;
			createBuffers();
			Starling.current.addEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
		}

		/** @inheritDoc */
		protected override function onVertexDataChanged():void
		{
			super.onVertexDataChanged();
			
			if(mVertexBuffer){
				mSyncRequired = true;
			}
			
			
		}
		/** Uploads the raw data of all batched quads to the vertex buffer. */
		private function syncBuffers():void
		{
			if (mVertexBuffer == null || mIndexBuffer == null)
			{
				createBuffers();
			}
			else
			{
				// as last parameter, we could also use 'mNumQuads * 4', but on some
				// GPU hardware (iOS!), this is slower than updating the complete buffer.
				copyVertexDataTransformedTo(_vertexData);
				mVertexBuffer.uploadFromVector(_vertexData.rawData, 0, mVertexData.numVertices);
				mSyncRequired = false;
			}
		}
		// program management
		private function createBuffers():void
		{
			mDeffTexture = texture as DeferredTexture;
			
			var pma:Boolean = texture ? texture.premultipliedAlpha : false;
			_vertexData.setPremultipliedAlpha(pma);
			
			copyVertexDataTransformedTo(_vertexData);
			
			//destroyBuffers();
			if (mVertexBuffer) mVertexBuffer.dispose(); //destroy last buffers
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			var numVertices:int = _vertexData.numVertices;
			var numIndices:int = mIndexData.length;
			
			var context:Context3D = Starling.context;
			if (context == null)  throw new MissingContextError();
			
			mVertexBuffer = context.createVertexBuffer(numVertices, VertexData.ELEMENTS_PER_VERTEX);
			mVertexBuffer.uploadFromVector(_vertexData.rawData, 0, numVertices);
			
			mIndexBuffer = context.createIndexBuffer(numIndices);
			mIndexBuffer.uploadFromVector(mIndexData, 0, numIndices);
			
			mSyncRequired = false;
			
		}
		private function getProgram(_flat:Boolean,_translucent:Boolean,_selection:Boolean,_wind:Boolean):Program3D
		{
			var target:Starling = Starling.current;

			programName = getProgramName(_flat,_translucent,_selection,_wind);
			
			var program:Program3D = target.getProgram(programName);
			
			if (!program)
			{
				// this is the input data we'll pass to the shaders:
				// 
				// va0 -> position
				// va1 -> color
				// va2 -> texCoords
				// vc0 -> mvpMatrix
				//vc4 - offsets uv(x,y -normal),(z,w -depth)
				
				//fc0 -> constants [0,1,0.5,0]
				//fc1 -> mCaordinates x -> alpha.yz -> yz
				//fc2 -> mNormalConstant [0.5,0.5,1,1]
				//fc3 -> mSelection;
				//fc4 -> mUVStartStop -> uvX start, uvYStart,uvXEnd,uvYEnd;
				//fc5 -> Offsets 
				//fc6 -> constants2 [0.1,0.3,0.7,0.9];
				//fc7 -> mProperties [ScaleX,ScaleY,Emissive,Depth];
				//fc8 -> mWind [Wind Strenght,3,0.3,4.5];
				//fc9 -> mColor [color red,green,blue,0];
				
				vertexShader =
					"m44 op, va0, vc0 \n" + // 4x4 matrix transform to output clipspace
					//"mov v0, va0      \n"+ 
					"mov v1, va1      \n"+  // pass texture coordinates to fragment program
					"add v2, va1, vc4.xy \n" + // offset uv to match normal
					"add v3, va1, vc4.zw \n"; // offset uv to match depth
				
				fragmentShader =
					
					"sub ft5.xy ,v1.xy,fc4.xy          \n"+				//move uv gradient to 0 start
					"mul ft5.xy ,ft5.xy ,fc4.zw             \n"+			//and multiply by 1/(uvYEnd-uvYStart) and get uv gradient from 0 to 1
					"sub ft5.xy ,ft5.xy ,fc0.xy              \n"+ //uv - 1
					"neg ft5.xy ,ft5.xy           \n"+						//reverse gradient. Uv * -1
					
					
					"<wind_part>"+
					
					"<flat_part>"+ //replace sampler with constant value
					//"mul ft3.xyz, ft3.xyz ,ft3.www     \n" +//restore pma
					
					
					//flat depth gradient by given depth properties value
					"sub ft2.x, ft2.x ,fc0.z     \n"+//sub 0.5 to move from [0,1] to [-0.5,0.5]
					"mul ft2.x, ft2.x ,fc7.w     \n"+ //mul by depth properties
					"add ft2.x, ft2.x ,fc0.z     \n"+//add 0.5 to move from [-0.5,0.5] to [0,1]
					
					
					"mul ft2.x, ft2.x ,fc7.x     \n"+//mul depth by scaleY
					"mul ft2.x, ft2.x ,fc1.y     \n"+//mul depth by y position
					"add ft2.x, ft2.x ,fc1.z     \n"+//add depth by z position
					
					"add ft2.y, ft2.y ,fc7.z     \n"+ //add emissive

					"mul ft1.xyz, ft1.xyz ,fc9.xyz     \n"+//mul by color tint
					
					"<Selection>"+
					
					//"mov fo0.xyzw,ft1.xyzw       \n"+
					//"mul ft1.xyz, ft1.xyz ,ft1.www     \n"+ // restore pma
	
					
					"<OpaqueORTranslucent>";
		
				fragmentShader = fragmentShader.replace("<wind_part>",_wind?windPart:noWindPart);
				fragmentShader = fragmentShader.replace("<flat_part>",_flat?flatPart:emptyPart);
				fragmentShader = fragmentShader.replace("<Selection>",_selection?selectionPart:emptyPart);
				fragmentShader = fragmentShader.replace("<OpaqueORTranslucent>",_translucent?translucentPart:opaquePart);
				program = target.registerProgramFromSource(programName,vertexShader, fragmentShader);
			}
			return program;
		}
		
		private static const emptyPart:String = ""; 
		
		private static const opaquePart:String = 
			"mov fo0,ft1       \n"+ //move to DiffRT
			
			"mul ft2.x, ft2.x ,ft2.w    \n"+ //get rid of unwanted transparent pixels
			"mov fo2, ft2      \n"+//write do depthRT
			"mov fo1.xyzw, ft3.xyzw     \n"+//and write do normalRT
			
			"neg ft2.x, ft2.x     \n"+//invert depth map and write to zbuffer 
			"add fd.x, ft2.x, fc0.y      \n"; //+1
		
		private static const translucentPart:String = 
			"mul ft1.xyzw, ft1.xyzw ,fc1.xxxx     \n"+  //set alpha
			"mov fo0,ft1       \n"+ //move to DiffRT
			
			"mov ft4.xz, fc0.xx      \n"+ //move 0 to everything besides emmisive
			"mul ft4.y, ft2.y ,ft1.x    \n"+ //restore pma //move emmisive
			"mov ft4.w, fc0.y      \n"+ //move emmisive
			"mul ft4.xyzw, ft4.xyzw ,fc1.xxxx     \n"+  //set alpha on emissive
			
			"mov fo2, ft4      \n"+//write do depthRT 
			"mov fo1.xyzw, fc0.xxxx     \n"+//and write do normalRT 0
			
			"neg ft2.x, ft2.x     \n"+//invert depth map and write to zbuffer 
			"add fd.x, ft2.x, fc0.y      \n"; //+1
		
		
		private static const flatPart:String = 
			"mov ft2.xyz, fc0.zxx   \n"+  // sample depth flat color 
			
			"mul ft2.xyz, ft2.xyz,ft5.yyy  \n"+ // add gradient
			
			"mov ft2.w, ft1.w   \n"+ 
			
			"mov ft3.xyz, fc2.xyz    \n"+ //sample normal flat color 
			"mov ft3.w, ft1.w   \n";
		
		
		private static const noWindPart:String = 
			"tex  ft1,  v1, fs0 <2d, clamp, linear, mipnone> \n"+  // sample texture 0 and write do diffuseRT	
			"tex  ft3,  v2, fs0 <2d, clamp, linear, mipnone> \n"+  // sample texture 0 (normal) 
			"tex  ft2,  v3, fs0 <2d, clamp, linear, mipnone> \n";  // sample texture 0 (depth)
		
		
		private static const windPart:String = 
			//"sub ft4, ft5.y, fc0.y  \n" +  //offset = 1-y
			"mov  ft4.xyzw ,ft5.yyyy,  \n" + 
			"pow ft4, ft4, fc8.w    \n" +  //offset = offset^4.5
			"mul ft4, ft4.y, fc8.x     \n" +  //offset = sin(count)*offset
			"mul ft4, ft4, fc8.z    \n" +  //offset *= .3
			//	"sat ft4.x, ft4.x  \n" +  //clamp to max value to not go outside his uv
			"mul ft4.x, ft4.x, ft5.x    \n" +  //
			//"sub ft4.x, ft5.x, ft4.x    \n" +  //clamp to max value to not go outside his uv
			
			"mov ft1 ,v1  \n" + 
			"add ft1.x, v1.x, ft4.x        \n" +  //texturePos.x += offset
			
			"tex ft1, ft1,  fs0 <2d, clamp, linear, mipnone>  \n" + //pixel = texture(texturePos)
			
			"mov ft3 ,v2  \n" + 
			"add ft3.x, v2.x, ft4.x        \n" +  //texturePos.x += offset
			"tex  ft3,  ft3, fs0 <2d, clamp, linear, mipnone> \n"+  // sample texture 0 (normal) 
			
			"mov ft2 ,v3  \n" + 
			"add ft2.x, v3.x, ft4.x        \n" +  //texturePos.x += offset
			"tex  ft2,  ft2, fs0 <2d, clamp, linear, mipnone> \n"; // sample texture 0 (depth)
		
		
		private static const selectionPart:String = 
			"mov ft4.xyzw , fc0.xxxx               \n"+		
			"mov ft6 , fc6.yyy               \n"+		//prepare iluminated quad
			"mov ft6.w , fc0.x              \n"+		//add result to output
			
			"add ft4 , v1 ,fc5.zwxx                \n"+	// -x, -y
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"mov ft4, v1 \n" + // reset
			"add ft4.y, v1.y, fc5.y \n" + // 0, -y	
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"add ft4, v1, fc5.xwxx  \n" + // x ,y
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"mov ft4, v1 \n" + // reset
			"add ft4.x, v1.x, fc5.z  \n" + // -x,0
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"mov ft4, v1 \n" + // reset
			"add ft4.x, v1.x, fc5.x  \n" + // x,0
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"add ft4, v1, fc5.zwxx  \n" + // -x,-y
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"mov ft4, v1 \n" + // reset
			"add ft4.y, v1.y, fc5.y  \n" + // 0,y
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			"add ft4, v1, fc5.xyxx  \n"+  // x,y
			"tex ft4, ft4,  fs0 <2d, clamp, linear, mipnone>  \n" + // read offset pixel 
			"slt ft7.xyzw, ft4.w,fc6.x                  \n"+ //if alpha is less than 0.5, make it black. Other make white
			"mov ft7.w , ft4.w              \n"+		//add result to output
			"add ft6 ,ft6 ,ft7               \n"+		//add result to output
			
			
			//GRADIENT***********************
			"mov ft4.x ,ft5.y           \n"+ // put gradient to ft4
			"mul ft4.x,ft4.x, ft4.x               \n"+			// offset gradient	
			
			"mul ft6.xyz ,ft4.xxxx ,ft6.xyz             \n"+///mul by gradient
			//***************************************
			
			//SEPARATE OUTLINE***********************
			/*"mov ft4.w ,ft6.w             \n"+
			"neg ft6.w ,ft1.w           \n"+//invert alpha
			"add ft6.w,ft6.w, fc0.y      \n"+ //+1
			"mul ft6.w ,ft6.w ,ft4.w              \n"+*/
			//***************************************
			
			
			"add ft2.y,ft2.y, ft6.x     \n"+ //add to emmisive
			
			"mul ft6.xyz ,ft6.xyz ,fc3.xyz              \n"+//add color
			
			"add ft1.xyz ,ft1.xyz ,ft6.xyz             \n";///add to output
			
		
		public function getProgramName(_flat:Boolean, _translucent:Boolean, _selection:Boolean, _wind:Boolean):String {
		
			tempProgramName = (1 | uint(_flat)*2) | (uint(_translucent)*4) | (uint(_selection)*8) | (uint(_wind)*16); //bitwise 10011100 etc
			
			return tempProgramName.toString(2);
		}
		/** @inheritDoc */
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
			if(mTranslucent){
				if(DeferredRenderer.DeferredPass != DeferredRenderer.TRANSLUCENTS){return}
			}else{
				if(DeferredRenderer.DeferredPass != DeferredRenderer.MRT){return};
			}
			
			
			if (mSyncRequired) syncBuffers();
			
			mDeffTexture = texture as DeferredTexture;
			
			// always call this method when you write custom rendering code!
			// it causes all previously batched quads/images to render.
			//support.finishQuadBatch(); // (1)
			
			// make this call to keep the statistics display in sync.
			support.raiseDrawCount(); // (2)	
			
			tempCgBody = getCgBody();
			//SELECTION PROPERTIES
			//offsets
			if(mSelectedFilter){
				mOffsets[0] = (1 /  mDeffTexture.diffuse.root.width)*mSelectedFilter.mSize; //x     pixel clamped to 0-1
				mOffsets[1] = (1 /  mDeffTexture.diffuse.root.height)*mSelectedFilter.mSize; //y
				mOffsets[2] = ((1 /  mDeffTexture.diffuse.root.width)*mSelectedFilter.mSize)*(-1);
				mOffsets[3] = ((1 /  mDeffTexture.diffuse.root.height)*mSelectedFilter.mSize)*(-1);
			}
			if(mWindFilter){
				mWind[0] = mWindFilter.strength;
			}
			//END SELECTION PROPERTIES
			
			mUvOffsets[0] = mDeffTexture.normalUvOffset.x;
			mUvOffsets[1] = mDeffTexture.normalUvOffset.y;
			mUvOffsets[2] = mDeffTexture.depthUvOffset.x;
			mUvOffsets[3] = mDeffTexture.depthUvOffset.y;
			
			_vertexData.getTexCoords(0,tempPoint); // up vertex
			mUVStartStop[0] = 	tempPoint.x;
			mUVStartStop[1] =   tempPoint.y;
			_vertexData.getTexCoords(3,tempPoint); ///bottom vertex
			mUVStartStop[2] = 	1/(tempPoint.x-mUVStartStop[0]);
			mUVStartStop[3] =   1/(tempPoint.y-mUVStartStop[1]);
			
			mCaordinates[0] = this.alpha*parentAlpha;
			mCaordinates[1] = (tempCgBody.y / Camera.worldFarPlane)*2;
			
			//add caordinates do z buffer
			if(tempCgBody.sorting == CgBody.SORT_NORMAL){
				mCaordinates[2] = (tempCgBody.z)/ Camera.worldFarPlane;
			}else if(tempCgBody.sorting == CgBody.SORT_BELOW){
				mCaordinates[2] = 1;
			}else{
				mCaordinates[2] = 0;
			}
			
			mCaordinates[3] = mDepth;
			mProperties[0] = this.scaleX;
			mProperties[1] = this.scaleY;
			mProperties[2] = mEmissive;
			mProperties[3] = mDepth;
			
			mColor[0] = Color.getRed(tempCgBody.color) /255; 
			mColor[1] = Color.getGreen(tempCgBody.color) /255; 
			mColor[2] = Color.getBlue(tempCgBody.color) /255; 

			var context:Context3D = Starling.context; // (3)
			if (context == null) throw new MissingContextError();
			
			context.setProgram(getProgram(mDeffTexture.isFlat,mTranslucent,mSelectedFilter?true:false,mWindFilter?true:false));
			context.setVertexBufferAt(0, mVertexBuffer, VertexData.POSITION_OFFSET, Context3DVertexBufferFormat.FLOAT_3); 
			context.setVertexBufferAt(1, mVertexBuffer, VertexData.TEXCOORD_OFFSET, Context3DVertexBufferFormat.FLOAT_2);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, support.mvpMatrix3D, true);       
			context.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,mUvOffsets);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, mConstants);	
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, mCaordinates);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, mNormalConstant);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, mSelectedFilter?mSelectedFilter.color:mConstants);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 4, mUVStartStop);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 5, mOffsets);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 6, mConstants2);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 7, mProperties);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 8, mWind);
			context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 9, mColor);
			context.setTextureAt(0, mDeffTexture.normal.base);
			// finally: draw the object! (6)
			
			context.drawTriangles(mIndexBuffer, 0, 2);
			
			// reset buffers (7)
			context.setTextureAt(0, null);
			context.setVertexBufferAt(0, null);
			//context.setVertexBufferAt(1, null);
			context.setVertexBufferAt(1, null);
		}
		/**Search (by parent tree) cgBody that this is attached to*/
		private function getCgBody(_do:DisplayObject=null):CgBody{
			if(_do == null){_do = parent}
			if(_do is CgBody){return (_do as CgBody);}else{
				if(_do.parent == null){
					throw new ArgumentError("Deferred image/movieClip not attached to cgBody");
				}
				return getCgBody(_do.parent);
			}
		}
		public override function dispose():void
		{
			Starling.current.removeEventListener(Event.CONTEXT3D_CREATE, onContextCreated);
			
			if (mVertexBuffer) mVertexBuffer.dispose();
			if (mIndexBuffer)  mIndexBuffer.dispose();
			
			super.dispose();
		}
		private function onContextCreated(event:Event):void
		{
			createBuffers();
		}
		public function set depth(value:Number):void{
			mDepth = Camera.calculateDepth(value);
		}
		public function get depth():Number{
			return mDepth;
		}
		public function set emissive(value:Number):void{
			mEmissive = value;
		}
		public function get emissive():Number{
			return mEmissive;
		}
	
		public function set translucent(value:Boolean):void{
			mTranslucent = value;
		}
		public function get translucent():Boolean{
			return mTranslucent;
		}
		public function set selection(filter:DeferredSelectionFilter):void{
			mSelectedFilter = filter;
		}
		public function get selection():DeferredSelectionFilter{
			return mSelectedFilter;
		}
		public function set wind(value:LocalWindForce):void{
			mWindFilter = value;
		}
		public function get wind():LocalWindForce{
			return mWindFilter;
		}
		override public function set filter(value:FragmentFilter):void {
			if(value == null){super.filter = null}else{
				throw new ArgumentError("Filters not working with current Deffered Body") 
			}
		}
		override public function set mask(value:DisplayObject):void{
			
			if(value == null){super.mask = null}else{
				throw new ArgumentError("Masks not working with current Deffered Body");
			}
			
			
		}
	}
}